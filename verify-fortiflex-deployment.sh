#!/bin/bash
#
# verify-fortiflex-deployment.sh
# Quick verification script for FortiFlex Marketplace deployment in K8s
#

set -e

echo "=========================================="
echo "FortiFlex Marketplace Deployment Check"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check AWS profile
if [ -z "$AWS_PROFILE" ]; then
    echo -e "${YELLOW}⚠️  AWS_PROFILE not set, using default${NC}"
else
    echo -e "${GREEN}✓${NC} Using AWS profile: $AWS_PROFILE"
fi
echo ""

# 1. Check pod status
echo "1. Checking Pod Status..."
BACKEND_POD=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pods -n default -l app=vm-poc-backend-fortiflex-marketplace -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
FRONTEND_POD=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pods -n default -l app=vm-poc-frontend-fortiflex-marketplace -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$BACKEND_POD" ]; then
    echo -e "${RED}✗ Backend pod not found${NC}"
    exit 1
else
    BACKEND_STATUS=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $BACKEND_POD -n default -o jsonpath='{.status.phase}')
    BACKEND_READY=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $BACKEND_POD -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    BACKEND_AGE=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $BACKEND_POD -n default -o jsonpath='{.metadata.creationTimestamp}')
    
    if [ "$BACKEND_STATUS" = "Running" ] && [ "$BACKEND_READY" = "True" ]; then
        echo -e "   ${GREEN}✓${NC} Backend: $BACKEND_POD (Running, Ready)"
    else
        echo -e "   ${RED}✗${NC} Backend: $BACKEND_POD (Status: $BACKEND_STATUS, Ready: $BACKEND_READY)"
    fi
fi

if [ -z "$FRONTEND_POD" ]; then
    echo -e "${RED}✗ Frontend pod not found${NC}"
    exit 1
else
    FRONTEND_STATUS=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $FRONTEND_POD -n default -o jsonpath='{.status.phase}')
    FRONTEND_READY=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $FRONTEND_POD -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    if [ "$FRONTEND_STATUS" = "Running" ] && [ "$FRONTEND_READY" = "True" ]; then
        echo -e "   ${GREEN}✓${NC} Frontend: $FRONTEND_POD (Running, Ready)"
    else
        echo -e "   ${RED}✗${NC} Frontend: $FRONTEND_POD (Status: $FRONTEND_STATUS, Ready: $FRONTEND_READY)"
    fi
fi
echo ""

# 2. Check image versions
echo "2. Checking Container Images..."
BACKEND_IMAGE=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $BACKEND_POD -n default -o jsonpath='{.spec.containers[0].image}' | cut -d'@' -f1)
BACKEND_SHA=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $BACKEND_POD -n default -o jsonpath='{.status.containerStatuses[0].imageID}' | grep -o 'sha256:[a-f0-9]*' | cut -c1-19 || echo "unknown")
echo -e "   ${GREEN}✓${NC} Backend:  ${BACKEND_IMAGE}"
echo -e "     Image SHA: ${BACKEND_SHA}"

FRONTEND_IMAGE=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $FRONTEND_POD -n default -o jsonpath='{.spec.containers[0].image}' | cut -d'@' -f1)
FRONTEND_SHA=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get pod $FRONTEND_POD -n default -o jsonpath='{.status.containerStatuses[0].imageID}' | grep -o 'sha256:[a-f0-9]*' | cut -c1-19 || echo "unknown")
echo -e "   ${GREEN}✓${NC} Frontend: ${FRONTEND_IMAGE}"
echo -e "     Image SHA: ${FRONTEND_SHA}"
echo ""

# 3. Check recent logs for errors
echo "3. Checking Recent Logs (last 20 lines)..."
echo "   Backend logs:"
AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl logs -n default $BACKEND_POD --tail=20 | grep -i "error\|exception\|failed" || echo -e "   ${GREEN}✓${NC} No errors found"
echo ""
echo "   Frontend logs:"
AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl logs -n default $FRONTEND_POD --tail=20 | grep -i "error\|exception\|failed" || echo -e "   ${GREEN}✓${NC} No errors found"
echo ""

# 4. Test external endpoints
echo "4. Testing External Endpoints..."
BACKEND_URL="https://fortiflex-marketplace-api.fortinetcloudcse.com/api/products"
BACKEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL" 2>/dev/null || echo "000")
if [ "$BACKEND_CODE" = "200" ]; then
    echo -e "   ${GREEN}✓${NC} Backend API: $BACKEND_URL → $BACKEND_CODE"
else
    echo -e "   ${RED}✗${NC} Backend API: $BACKEND_URL → $BACKEND_CODE"
fi

FRONTEND_URL="https://fortiflex-marketplace.fortinetcloudcse.com/"
FRONTEND_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null || echo "000")
if [ "$FRONTEND_CODE" = "200" ]; then
    echo -e "   ${GREEN}✓${NC} Frontend: $FRONTEND_URL → $FRONTEND_CODE"
else
    echo -e "   ${RED}✗${NC} Frontend: $FRONTEND_URL → $FRONTEND_CODE"
fi
echo ""

# 5. Check ingress configuration
echo "5. Checking Ingress Configuration..."
BACKEND_TIMEOUT=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get ingress vm-poc-backend-fortiflex-marketplace-ingress -n default -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/load-balancer-attributes}' 2>/dev/null || echo "not set")
if [[ "$BACKEND_TIMEOUT" == *"300"* ]]; then
    echo -e "   ${GREEN}✓${NC} Backend ALB timeout: $BACKEND_TIMEOUT"
else
    echo -e "   ${YELLOW}⚠️${NC} Backend ALB timeout: $BACKEND_TIMEOUT (expected 300s)"
fi

BACKEND_HOST=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get ingress vm-poc-backend-fortiflex-marketplace-ingress -n default -o jsonpath='{.spec.rules[0].host}')
echo -e "   ${GREEN}✓${NC} Backend host: $BACKEND_HOST"

FRONTEND_HOST=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get ingress vm-poc-frontend-fortiflex-marketplace-ingress -n default -o jsonpath='{.spec.rules[0].host}')
echo -e "   ${GREEN}✓${NC} Frontend host: $FRONTEND_HOST"
echo ""

# 6. Check for recent events/errors
echo "6. Checking Recent K8s Events..."
ERROR_COUNT=$(AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get events -n default --field-selector type=Warning --sort-by='.lastTimestamp' | grep fortiflex | tail -5 | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "   ${GREEN}✓${NC} No recent warning events"
else
    echo -e "   ${YELLOW}⚠️${NC} Found $ERROR_COUNT recent warnings:"
    AWS_PROFILE=${AWS_PROFILE:-our-eks} kubectl get events -n default --field-selector type=Warning --sort-by='.lastTimestamp' | grep fortiflex | tail -5
fi
echo ""

echo "=========================================="
echo -e "${GREEN}Verification Complete!${NC}"
echo "=========================================="
