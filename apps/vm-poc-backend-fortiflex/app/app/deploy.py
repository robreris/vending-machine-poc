# Placeholder for Terraform orchestration
# backend/app/deploy.py
import json, os, subprocess, uuid
from typing import Dict

TF_STATE_BUCKET = os.getenv("TF_STATE_BUCKET")
TF_STATE_TABLE  = os.getenv("TF_STATE_TABLE")   # DynamoDB lock table

def run_tf(module_dir: str, tfvars: Dict, workspace: str):
    run_id = str(uuid.uuid4())
    tfvars_file = f"/tmp/{run_id}.tfvars.json"
    with open(tfvars_file, "w") as f:
        json.dump(tfvars, f)

    backend_cfg = [
      f"-backend-config=bucket={TF_STATE_BUCKET}",
      f"-backend-config=key=marketplace/{workspace}.tfstate",
      f"-backend-config=region={os.getenv('AWS_REGION','us-west-2')}",
      f"-backend-config=dynamodb_table={TF_STATE_TABLE}",
      "-backend-config=encrypt=true"
    ]

    subprocess.run(["terraform","-chdir",module_dir,"init","-upgrade","-reconfigure",*backend_cfg], check=True)
    subprocess.run(["terraform","-chdir",module_dir,"apply","-auto-approve",f"-var-file={tfvars_file}"], check=True)
    out = subprocess.run(["terraform","-chdir",module_dir,"output","-json"], check=True, capture_output=True)
    return json.loads(out.stdout)