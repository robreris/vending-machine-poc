import logging
import os
from functools import lru_cache
from typing import List, Dict, Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import APIRouter

logger = logging.getLogger(__name__)

router = APIRouter()

_FALLBACK_PRODUCTS: List[Dict[str, Any]] = [
    {
        "id": "1",
        "name": "FortiGate VM Base",
        "sku": "FG-VM-BUNDLE",
        "cloud": "AWS",
        "price": "0.12/hr",
        "description": "1 vCPU, 2GB RAM, basic firewall",
        "title": "FortiGate VM01 Base",
        "image_url": "images/FortiGate-VM01.png",
    },
    {
        "id": "2",
        "name": "FortiGate VM Advanced",
        "sku": "FG-VM-ADVANCED",
        "cloud": "AWS",
        "price": "0.24/hr",
        "description": "2 vCPU, 4GB RAM, advanced firewall features",
        "title": "FortiGate VM02 Advanced",
        "image_url": "images/FortiGate-VM02.png",
    },
    {
        "id": "3",
        "name": "FortiGate VM HA",
        "sku": "FG-VM-HA",
        "cloud": "AWS",
        "price": "0.48/hr",
        "description": "4 vCPU, 8GB RAM, premium firewall features",
        "title": "FortiGate VM03 Premium",
        "image_url": "images/FortiGate-VM-HA.png",
    },
    {
        "id": "4",
        "name": "FortiGate VM MAX",
        "sku": "FG-VM-MAX",
        "cloud": "AWS",
        "price": "0.96/hr",
        "description": "8 vCPU, 16GB RAM, enterprise-grade firewall",
        "title": "FortiGate VM MAX",
        "image_url": "images/FortiGate-VM-MAX.png",
    },
    {
        "id": "5",
        "name": "FortiGate FLEX",
        "sku": "FG-FLEX",
        "cloud": "AWS",
        "price": "1.92/hr",
        "description": "16 vCPU, 32GB RAM, ultimate firewall features",
        "title": "FortiGate FLEX",
        "image_url": "images/FortiGate-Flex.png",
    },
]


def _dynamodb_resource_kwargs() -> Dict[str, Any]:
    kwargs: Dict[str, Any] = {}
    region = os.getenv("AWS_REGION")
    endpoint = os.getenv("AWS_ENDPOINT_URL_DYNAMODB")
    if region:
        kwargs["region_name"] = region
    if endpoint:
        kwargs["endpoint_url"] = endpoint
    return kwargs


@lru_cache(maxsize=1)
def _products_table():
    table_name = os.getenv("PRODUCTS_TABLE_NAME")
    if not table_name:
        logger.info("PRODUCTS_TABLE_NAME not set; serving fallback catalog.")
        return None

    try:
        dynamodb = boto3.resource("dynamodb", **_dynamodb_resource_kwargs())
        return dynamodb.Table(table_name)
    except (BotoCoreError, ClientError) as exc:
        logger.warning("Unable to initialise DynamoDB table %s: %s", table_name, exc)
        return None


@router.get("/api/products")
def get_products() -> List[Dict[str, Any]]:
    table = _products_table()
    if not table:
        return _FALLBACK_PRODUCTS

    try:
        response = table.scan()
    except (BotoCoreError, ClientError) as exc:
        logger.warning(
            "Failed to read products from DynamoDB table %s: %s", table.name, exc
        )
        return _FALLBACK_PRODUCTS

    items: List[Dict[str, Any]] = response.get("Items", [])
    if not items:
        logger.info("DynamoDB table %s is empty; returning fallback catalog.", table.name)
        return _FALLBACK_PRODUCTS

    return sorted(items, key=lambda item: item.get("id", ""))
