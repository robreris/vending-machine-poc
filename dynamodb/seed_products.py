#!/usr/bin/env python3
"""Seed the shared products DynamoDB table with catalog entries."""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def parse_args() -> argparse.Namespace:
    default_seed = Path(__file__).with_name("products_seed.json")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--table-name",
        required=True,
        help="Target DynamoDB table name (creates the table if it does not exist).",
    )
    parser.add_argument(
        "--region",
        default=None,
        help="AWS region for the DynamoDB API (defaults to AWS_REGION env).",
    )
    parser.add_argument(
        "--endpoint-url",
        default=None,
        help="Optional DynamoDB endpoint override (useful for DynamoDB Local).",
    )
    parser.add_argument(
        "--seed-file",
        type=Path,
        default=default_seed,
        help=f"Path to JSON seed data (defaults to {default_seed.name}).",
    )
    return parser.parse_args()


def load_seed_data(path: Path) -> List[Dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError as exc:
        raise SystemExit(f"Seed file not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc

    if not isinstance(data, list):
        raise SystemExit(f"Seed data must be a list of products, got: {type(data)}")
    return data


def ensure_table(client, table_name: str) -> None:
    try:
        client.describe_table(TableName=table_name)
        return
    except client.exceptions.ResourceNotFoundException:
        pass
    except ClientError as exc:
        raise SystemExit(f"Failed to describe table {table_name}: {exc}") from exc

    try:
        client.create_table(
            TableName=table_name,
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        client.get_waiter("table_exists").wait(TableName=table_name)
        print(f"Created DynamoDB table {table_name}")
    except ClientError as exc:
        raise SystemExit(f"Failed to create table {table_name}: {exc}") from exc


def seed_table(
    table, products: List[Dict[str, Any]], overwrite_keys: Optional[List[str]] = None
) -> None:
    overwrite_keys = overwrite_keys or ["id"]
    try:
        with table.batch_writer(overwrite_by_pkeys=overwrite_keys) as batch:
            for product in products:
                batch.put_item(Item=product)
    except (BotoCoreError, ClientError) as exc:
        raise SystemExit(f"Failed to write seed data: {exc}") from exc


def main() -> int:
    args = parse_args()
    session_kwargs: Dict[str, Any] = {}
    if args.region:
        session_kwargs["region_name"] = args.region
    resource_kwargs: Dict[str, Any] = session_kwargs.copy()
    if args.endpoint_url:
        resource_kwargs["endpoint_url"] = args.endpoint_url

    products = load_seed_data(args.seed_file)

    resource = boto3.resource("dynamodb", **resource_kwargs)
    client = resource.meta.client
    ensure_table(client, args.table_name)
    table = resource.Table(args.table_name)

    seed_table(table, products)
    print(f"Seeded {len(products)} products into {args.table_name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
