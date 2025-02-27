#!/bin/bash

# Defining Variables and Paths
DATE="0303_100" # Change to appropriate date (or data folder)!
SENSOR="flirIrCamera"

PIPE_PATH='/xdisk/ericlyons/big_data/cosi/PhytoOracle/FlirIr/'
SIMG_PATH='/xdisk/ericlyons/big_data/singularity_images/'

FLIR_DIR="flir2tif_out/"
BIN_DIR="bin2tif_out/"
STITCH_ORTHO_DIR="stitched_ortho_out/"
PLOTCLIP_DIR="plotclip_out/"
GPS_DIR="gpscorrect_out/"

ORTHO_PATH=${PIPE_PATH}'ortho_out'
CSV_PATH=${PIPE_PATH}'img_coords_out/'${DATE}'_coordinates.csv'
GPS_CS_PATH=${ORTHO_PATH}"${DATE}_out/${DATE}_coordinates_CORRECTED.csv"

# Phase 1: CCTools Parallelization to HPC nodes (Image conversion)
python3 gen_files_list.py ${DATE} > raw_data_files.json
python3 gen_bundles_list.py raw_data_files.json bundle_list.json 50
mkdir -p bundle/
python3 split_bundle_list.py  bundle_list.json bundle/
/home/u12/cosi/cctools-7.1.6-x86_64-centos7/bin/jx2json main_wf_phase1.jx -a bundle_list.json > main_workflow_phase1.json

# -a advertise to catalog server
/home/u12/cosi/cctools-7.1.6-x86_64-centos7/bin/makeflow -T wq --json main_workflow_phase1.json -a -N phyto_oracle_FLIR -p 9123 -M PhytoOracle_FLIR -dall -o dall.log -r 100 --disable-cache $@

# Phase 2: Parallelization on single node (GPS correction)
#module load singularity/3.2.1
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}collect_gps_latest.simg  --scandate ${DATE} ${FLIR_DIR}

mkdir -p ${ORTHO_PATH}/${DATE}/
mkdir -p ${ORTHO_PATH}/${DATE}/SIFT/
mkdir -p ${ORTHO_PATH}/${DATE}/logs/

singularity exec ${SIMG_PATH}full_geocorrection.simg python3 ../Lettuce_Image_Stitching/Dockerized_GPS_Correction_FLIR.py -d ${ORTHO_PATH} -s ${DATE} -c ../Lettuce_Image_Stitching/geo_correction_config.txt -l ./lids.txt -b ${FLIR_DIR} -r ../Lettuce_Image_Stitching

# Phase 3: Orthomosaic building and temperature extraction
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}flirfieldplot.simg -d ${DATE} -o ${STITCH_ORTHO_DIR} ${ORTHO_PATH}/${DATE}/output_tiffs/
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}plotclip_geo.simg -sen ${SENSOR} -shp season10_multi_latlon_geno_up.geojson -o ${PLOTCLIP_DIR} ${STITCH_ORTHO_DIR}${DATE}"_ortho_NaN.tif"
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}stitch_plots.simg ${PLOTCLIP_DIR} #This is only used to change the name == known issue
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}po_temp_cv2stats.simg -g season10_multi_latlon_geno_up.geojson -o plot_meantemp_out/ -d ${DATE} ${PLOTCLIP_DIR}

#singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}thermal_single.simg -m model_weights_flir_v3_full.pth -c 16 ${PLOTCLIP_DIR}*/*_ortho.tif
singularity run -B $(pwd):/mnt --pwd /mnt ${SIMG_PATH}flir_plant_temp.simg -d ${DATE}  -g season10_multi_latlon_geno_up.geojson -m model_weights_flir_v3_full.pth -c 20 ${PLOTCLIP_DIR}

