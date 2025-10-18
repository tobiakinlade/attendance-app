# Get the latest run ID and view the full logs
gh run view 18620163629 --log > drift-log.txt

# Check the exit code
echo "Exit code from Terraform Plan:"
grep "exit_code=" drift-log.txt

# Check what terraform plan output
echo ""
echo "Terraform Plan Output:"
grep -A 30 "Terraform Plan (Detect Drift)" drift-log.txt | head -50

# Check the drift detection logic
echo ""
echo "Drift Detection Check:"
grep -A 5 "Check for Drift" drift-log.txt
