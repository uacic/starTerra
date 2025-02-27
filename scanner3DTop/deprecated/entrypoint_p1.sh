#!/bin/bash

export CCTOOLS_HOME=${HOME}/cctools-7.1.12-x86_64-centos7
export PATH=${CCTOOLS_HOME}/bin:$PATH

#python3 gen_files_list.py 2020-03-02 RAW_DATA_PATH __Top-heading-east_0_g.png > raw_data_files.json
#python3 gen_bundles_list.py raw_data_files.json bundle_list.json 1
#mkdir -p bundle/
#python3 split_bundle_list.py bundle_list.json bundle/
jx2json main_workflow_phase1.jx -a bundle_list.json > main_workflow_phase1.json
makeflow -T wq --json main_workflow_phase1.json -a -N phytooracle_3d -M phytooracle_3d -r 3 -p 0 -dall -o dall.log $@
