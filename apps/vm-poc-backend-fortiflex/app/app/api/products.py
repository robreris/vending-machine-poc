from fastapi import APIRouter

router = APIRouter()

@router.get("/api/products")
def get_products():
    return [
        {
            "id": "1",
            "name": "FortiGate VM Base",
            "sku": "FG-VM-BUNDLE",
            "cloud": "AWS",
            "price": "0.12/hr",
            "description": "1 vCPU, 2GB RAM, basic firewall",
            "title": "FortiGate VM01 Base",
            "image_url": "images/FortiGate-VM01.png"
        },
        {
            "id": "2",
            "name": "FortiGate VM Advanced",
            "sku": "FG-VM-ADVANCED",
            "cloud": "AWS",
            "price": "0.24/hr",
            "description": "2 vCPU, 4GB RAM, advanced firewall features",
            "title": "FortiGate VM02 Advanced",
            "image_url": "images/FortiGate-VM02.png"
        },
        {
            "id": "3",
            "name": "FortiGate VM HA",
            "sku": "FG-VM-HA",
            "cloud": "AWS",
            "price": "0.48/hr",
            "description": "4 vCPU, 8GB RAM, premium firewall features",
            "title": "FortiGate VM03 Premium",
            "image_url": "images/FortiGate-VM-HA.png"
        },  
        {
            "id": "4",
            "name": "FortiGate VM MAX",
            "sku": "FG-VM-MAX",
            "cloud": "AWS",
            "price": "0.96/hr",
            "description": "8 vCPU, 16GB RAM, enterprise-grade firewall",
            "title": "FortiGate VM MAX",
            "image_url": "images/FortiGate-VM-MAX.png"
        },
        {
            "id": "5",
            "name": "FortiGate FLEX",
            "sku": "FG-FLEX",
            "cloud": "AWS",
            "price": "1.92/hr",
            "description": "16 vCPU, 32GB RAM, ultimate firewall features",
            "title": "FortiGate FLEX",
            "image_url": "images/FortiGate-Flex.png"
        }  
    ]
