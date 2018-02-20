#!/bin/bash
set -e

rm -rf ./output/*
pip3 install -r requirements.txt -t ./output
cp status_check.py ./output/
if [ -f "./status_check_lambda.zip" ];then
  rm ./status_check_lambda.zip
fi
cd ./output && zip -r ../status_check_lambda.zip *

# Run terraform apply
cd .. && terraform apply
