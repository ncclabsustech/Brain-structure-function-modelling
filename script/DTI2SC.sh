#!/bin/bash

#    SUBJECT_LIST='100206 100307 100408 100610 101006 101107 101309 101410 101915 102008 102109 190031 190132 191033 191235 191336 191437 191841 191942 192035 192136'
#SUBJECT_LIST='190031 190132 191033 191235 191336 191437 191841 191942 192035 192136 192237 192439 192550 192641 192843 193239 193441 193845 194140 194443 194645 194746 194847 195041 195445 195647 195849 195950 196144 196346 196750 971160 978578 979984 983773 887373 888678 '

#SUBJECT_LIST='196851 196952 200008 200109 894067 894673 894774 896778 896879 898176 899885 901038 984472 987074 987983 989987 990366 991267 992673 992774 993675 994273 996782'
#SUBJECT_LIST='889579 891667 901139 901442 902242 904044 905147 907656 908860 910241 911849 912447'
#SUBJECT_LIST='145127 145531 145632 145834 146129 146331 146432 146533 146634 146735 146836 146937 147030 147636 147737 148032 148133 148335 148436 170631'
SUBJECT_LIST='192237  195445  196144  812746  816653  844961  852455  884064  911849  962058  966975  979984'

# '193239  200614  828862  870861  896778  930449  984472  145632 149842  153833  194645  201818  837560  
# 872764  901139  943862  991267
# 145834  150524  153934  194746  809252  837964  873968  901442  947668  992673
# 146129  150625  154229  194847  810439  841349'






#'101006  148335  152427  192540  200210  826353  865363  894067  926862  978578'
# 192035  196851  820745  856968  887373'  
# 917558  966975  100307  147737  151829  
# 192136  196952  825048  857263  888678  
# 919966  969476  100408  148032  151930  
# 192237  200008  825553  859671  889579  ######
# 922854  970764  100610  148133  152225  
# 192439  200109  825654  861456  891667  
# 923755  971160


#'100206 100307 100408 100610 101006 101107 101309 101410 101915 102008 102109 190031'
#DATA_PATH="/home/lzc/Project/DTI_process/"
DATA_PATH="/home/lzc/zhichao/"
template_path='/home/lzc/brain_template'
MRtrix_LUT_DIR='/home/lzc/miniconda3/share/mrtrix3/labelconvert/'

PARCELLATION_CHOICES='aal aal2 brainnetome246fs brainnetome246mni craddock200 craddock400 desikan destrieux hcpmmp1 none perry512 yeo7fs yeo7mni yeo17fs yeo17mni'

T1_DATA="/T1w_acpc_dc_restore_brain.nii.gz"
T1_DATA_125mm="/T1w_acpc_dc_restore_1.25.nii.gz" #1.25mm
Brain_Mask='/brainmask_fs.nii.gz'
NODIF_Brain_Mask='/nodif_brain_mask.nii.gz'
DTI_DATA="/data.nii.gz"
B_VALUE="/bvals"
B_VECTOR="/bvecs"

freesurfer_list="brainnetome246fs desikan destrieux hcpmmp1 yeo7fs yeo17fs"
MNI_LIST="aal aal2 brainnetome246mni craddock200 craddock400 perry512 yeo7mni yeo17mni"




for i in $SUBJECT_LIST ; do
    T1_PATH=$DATA_PATH$i$T1_DATA
    T1_125_PATH=$DATA_PATH$i$T1_DATA_125mm
    DTI_PATH=$DATA_PATH$i$DTI_DATA
    B_VALUE_PATH=$DATA_PATH$i$B_VALUE
    B_VECTOR_PATH=$DATA_PATH$i$B_VECTOR

    PERSONAL_OUTPUT_PATH='/home/lzc/zhichao/'$i
    echo $PERSONAL_OUTPUT_PATH
    if [ ! -d $PERSONAL_OUTPUT_PATH ];then
        mkdir $PERSONAL_OUTPUT_PATH
    #    else
    #    rm -rf $PERSONAL_OUTPUT_PATH
    #    mkdir $PERSONAL_OUTPUT_PATH
    fi


       # Step 4: Generate 5TT image for ACT
    TT_mif=$PERSONAL_OUTPUT_PATH'/5TT.mif' 
    5ttgen fsl $T1_PATH $TT_mif -premasked -nthreads 6 -force
    echo "5ttgen"

    DWI_MIF_PATH=$PERSONAL_OUTPUT_PATH"/DWI.mif"
    
    # Step 1: Convert the diffusion images into a non-compressed format
    mrconvert $DTI_PATH $DWI_MIF_PATH -fslgrad $B_VECTOR_PATH $B_VALUE_PATH -datatype float32 -strides 0,0,0,1 -nthreads 6 -force

    # Geberate a neab b=0 image for visualization
    MeanB0_mif=$PERSONAL_OUTPUT_PATH'/meanb0.mif'
    dwiextract $DWI_MIF_PATH - -bzero -nthreads 6  | mrmath - mean $MeanB0_mif -axis 3 -nthreads 6 -force
    #echo "mrconvert"

    # Step 2: Estimate response functions for spherical deconvolution
    # Estimate the response function; note that here we are estimating multi-shell, multi-tissue response functions:
    WM_Response=$PERSONAL_OUTPUT_PATH'/response_wm.txt'
    GM_Response=$PERSONAL_OUTPUT_PATH'/response_gm.txt'
    CSF_Response=$PERSONAL_OUTPUT_PATH'/response_csf.txt'
    #DWI_MASK=$PERSONAL_OUTPUT_PATH'dwi_mask.mif'
    #dwi2response dhollander $DWI_MIF_PATH $WM_Response $GM_Response $CSF_Response # -mask $DWI_MASK
    RF_Voxels_mif=$PERSONAL_OUTPUT_PATH'/RF_voxels.mif'
    dwi2response msmt_5tt $DWI_MIF_PATH $TT_mif $WM_Response $GM_Response $CSF_Response -voxels $RF_Voxels_mif -nthreads 6 -force  # -mask $DWI_MASK
    echo "dwi2response"

    # Step 3: Perform spherical deconvolution
    WM_FOD=$PERSONAL_OUTPUT_PATH'/FOD_WM.mif'
    GM_FOD=$PERSONAL_OUTPUT_PATH'/FOD_GM.mif'
    CSF_FOD=$PERSONAL_OUTPUT_PATH'/FOD_CSF.mif'
    
    NODIF_BRAIN_MASK_PATH=$DATA_PATH$i$NODIF_Brain_Mask
    dwi2fod msmt_csd $DWI_MIF_PATH $WM_Response $WM_FOD $GM_Response $GM_FOD $CSF_Response $CSF_FOD -mask $NODIF_BRAIN_MASK_PATH -nthreads 6 -force
    echo "dwi2fod"

    TISSUE=$PERSONAL_OUTPUT_PATH'/tissues.mif'
    mrconvert $WM_FOD - -coord 3 0 -nthreads 6  | mrcat $CSF_FOD $GM_FOD - $TISSUE -axis 3 -nthreads 6 -force
    echo "mrconvert"

    
    template_image_path=$FSLDIR'/data/standard/MNI152_T1_2mm.nii.gz'
    template_mask_path=$FSLDIR'/data/standard/MNI152_T1_2mm_brain_mask.nii.gz'

    # Step 5: Generate the grey matter parcellation
    # Do MNI
    BRAIN_MASK_PATH=$DATA_PATH$i$Brain_Mask
    T1_mask=$BRAIN_MASK_PATH
    T1_mask_mif=$PERSONAL_OUTPUT_PATH'/T1_mask.mif'
    mrconvert $T1_mask $T1_mask_mif -nthreads 6 
    echo "mrconvert T1_mask.mif"
    T1_histmatch=$PERSONAL_OUTPUT_PATH'/T1_histmatch.nii'
    #T1_Resize=$PERSONAL_OUTPUT_PATH'/T1_Brain_Resize.nii'
    #mrconvert $T1_PATH $T1_Resize -vox 2
    echo "Resize Brain"

    mrhistmatch linear $T1_PATH $template_image_path -nthreads 6  -mask_input $T1_mask_mif -mask_target $template_mask_path -force - | mrconvert - $T1_histmatch -nthreads 6 -force # -strides -1,+2,+3
    echo "mrhistmatch"

    flirt_in_path=$T1_histmatch
    flirt_ref_path=$PERSONAL_OUTPUT_PATH'/template_masked.nii'
    mrcalc $template_image_path $template_mask_path -mult $flirt_ref_path -nthreads 6 -force #-strides -1,+2,+3
    T1_to_template=$PERSONAL_OUTPUT_PATH'/T1_to_template.mat'
    flirt -ref $flirt_ref_path -in $flirt_in_path -omat $T1_to_template -dof 12 -cost leastsq
    echo "flirt"
    

    fnirt_in_path=$T1_histmatch
    fnirt_in_mask_path=$PERSONAL_OUTPUT_PATH'/T1_mask.nii'
    fnirt_ref_path=$template_image_path
    fnirt_ref_mask_path=$template_mask_path
    mrconvert $T1_mask_mif $fnirt_in_mask_path -nthreads 6 -force
    echo "mrconvert"
    fnirt_config_basename='/usr/local/fsl/etc/flirtsch/T1_2_MNI152_2mm.cnf' #'T1_2_MNI152_2mm.cnf'

    T1_to_template_warpcoef=$PERSONAL_OUTPUT_PATH'/T1_to_template_warpcoef.nii'
    fnirt --config=$fnirt_config_basename --ref=$fnirt_ref_path --in=$fnirt_in_path --aff=$T1_to_template --refmask=$fnirt_ref_mask_path --inmask=$fnirt_in_mask_path --cout=$T1_to_template_warpcoef
    echo "fnirt finished"


    # Use result of registration to transform atlas parcellation to subject space
    template_to_T1_warpcoef=$PERSONAL_OUTPUT_PATH'/template_to_T1_warpcoef.nii'
    invwarp --ref=$T1_histmatch --warp=$T1_to_template_warpcoef --out=$template_to_T1_warpcoef
    echo "invwarp"


    # AAL1
    parc_image_path_aal=$template_path'/aal_for_SPM12/aal/ROI_MNI_V4.nii'
    parc_lut_file_aal=$template_path'/aal_for_SPM12/aal/ROI_MNI_V4.txt'
    mrtrix_lut_file_aal=$MRtrix_LUT_DIR'/aal.txt'

    aal_atlas_transformed=$PERSONAL_OUTPUT_PATH'/aal_atlas_transformed.nii.gz'
    applywarp --ref=$T1_histmatch --in=$parc_image_path_aal --warp=$template_to_T1_warpcoef --out=$aal_atlas_transformed --interp=nn    
    echo "applywarp"
    
    # 2 XUAN 1
    aal_parc=$PERSONAL_OUTPUT_PATH'/aal_parc.mif'
    labelconvert $aal_atlas_transformed $parc_lut_file_aal $mrtrix_lut_file_aal $aal_parc -nthreads 6 -force
    #mrconvert transformed_atlas_path parc.mif
    echo "labelconvert"
    

    mkdir /mnt/repo3/zhichao/dti_result/$i
    mv $PERSONAL_OUTPUT_PATH/* /mnt/repo3/zhichao/dti_result/$i
    
    # Step 5: Generate the tractogram
    num_streamlines=10000000
    tractogram_filepath=$PERSONAL_OUTPUT_PATH'/tractogram_'$num_streamlines'.tck'
    TT_mif=$PERSONAL_OUTPUT_PATH'/5TT.mif'
    tckgen $WM_FOD $tractogram_filepath -act $TT_mif -backtrack -crop_at_gmwmi -maxlength 250 -select $num_streamlines -seed_dynamic $WM_FOD -cutoff 0.06 -nthreads 6 
    echo "tckgen"

    # Step 6: use sift2 to determine streamline weights
    MU_txt=$PERSONAL_OUTPUT_PATH'/mu.txt'
    Weights_CSV=$PERSONAL_OUTPUT_PATH'/weights.csv'
    tcksift2 $tractogram_filepath $WM_FOD $Weights_CSV -act $TT_mif -out_mu $MU_txt -fd_scale_gm -nthreads 6 
    echo "tcksift2"

    # In the space of the DWI image
    #tdi_dwi_mif=$PERSONAL_OUTPUT_PATH'/tdi_dwi.mif'
    #tdi_t1_mif=$PERSONAL_OUTPUT_PATH'/tdi_T1.mif'
    #mu=$(head -n +1 $MU_txt)
    #tckmap $tractogram_filepath - -tck_weights_in $Weights_CSV -template $WM_FOD -precise | mrcalc - $mu -mult $tdi_dwi_mif
    #echo "tckmap"

    #In the space of the T1-weighted image
    #tckmap $tractogram_filepath - -tck_weights_in $Weights_CSV -template $T1_image -precise | mrcalc - $mu -mult $tdi_t1_mif


    #  Step 7: Generate the connectome
    AAL_Connectome=$PERSONAL_OUTPUT_PATH'/aal_connectome.csv'
    AAL_meanlength=$PERSONAL_OUTPUT_PATH'/aal_meanlength.csv'
    AAL_over_volume=$PERSONAL_OUTPUT_PATH'/aal_overvolume.csv'
    AAL_over_volume_diag0=$PERSONAL_OUTPUT_PATH'/aal_overvolume_diag0.csv'
    Assignment_CSV=$PERSONAL_OUTPUT_PATH'/assignments.csv'
    assignment_option='-assignment_radial_search 5' #'yeo7mni', 'yeo17mni'
    tck2connectome $tractogram_filepath $aal_parc $AAL_Connectome -tck_weights_in $Weights_CSV -symmetric -nthreads 6 
    tck2connectome $tractogram_filepath $aal_parc $AAL_meanlength -tck_weights_in $Weights_CSV -scale_length -stat_edge mean -symmetric -nthreads 6 
    
    tck2connectome $tractogram_filepath $aal_parc $AAL_over_volume -tck_weights_in $Weights_CSV -scale_invnodevol -stat_edge mean -symmetric -nthreads 6 
    tck2connectome $tractogram_filepath $aal_parc $AAL_over_volume_diag0 -tck_weights_in $Weights_CSV -scale_invnodevol -stat_edge mean -zero_diagonal -symmetric -nthreads 6 
    echo "tck2connectome"



    
    # Brainnetome
    parc_image_path_bnt=$template_path'/brainnetome/BN_Atlas_246_2mm.nii.gz'
    parc_lut_file_bnt=$template_path'/brainnetome/BN_Atlas_246_LUT.txt'
    mrtrix_lut_file_bnt=''
            
    BN_Atlas_transformed=$PERSONAL_OUTPUT_PATH'/BN_Atlas_transformed2.nii.gz'
    applywarp --ref=$T1_histmatch --in=$parc_image_path_bnt --warp=$template_to_T1_warpcoef --out=$BN_Atlas_transformed --interp=nn    
    echo "BN_Atlas applywarp"
    
    BN_Atlas_parc=$PERSONAL_OUTPUT_PATH'/BN_Atlas_parc2.mif'
    #labelconvert $BN_Atlas_transformed $parc_lut_file_aal $mrtrix_lut_file_aal $BN_Atlas_parc
    mrconvert $BN_Atlas_transformed $BN_Atlas_parc -nthreads 6 
    echo "labelconvert"

    BN_Atlas_Connectome=$PERSONAL_OUTPUT_PATH'/BN_Atlas_2mm_connectome.csv'
    BN_Atlas_meanlength=$PERSONAL_OUTPUT_PATH'/BN_Atlas_2mm_meanlength.csv'
    BN_Atlas_over_volume=$PERSONAL_OUTPUT_PATH'/BN_Atlas_2mm_overvolume.csv'
    BN_Atlas_over_volume_diag0=$PERSONAL_OUTPUT_PATH'/BN_Atlas_2mm_overvolume_diag0.csv'
    Assignment_CSV=$PERSONAL_OUTPUT_PATH'/assignments.csv'
    assignment_option='-assignment_radial_search 5' #'yeo7mni', 'yeo17mni'
    tck2connectome $tractogram_filepath $BN_Atlas_parc $BN_Atlas_Connectome -tck_weights_in $Weights_CSV -nthreads 6 
    tck2connectome $tractogram_filepath $BN_Atlas_parc $BN_Atlas_meanlength -tck_weights_in $Weights_CSV -scale_length -stat_edge mean -nthreads 6 
    tck2connectome $tractogram_filepath $BN_Atlas_parc $BN_Atlas_over_volume -tck_weights_in $Weights_CSV -scale_invnodevol -stat_edge mean -symmetric -nthreads 6 
    tck2connectome $tractogram_filepath $BN_Atlas_parc $BN_Atlas_over_volume_diag0 -tck_weights_in $Weights_CSV -scale_invnodevol -stat_edge mean -zero_diagonal -symmetric -nthreads 6 
    
    echo "tck2connectome" 

    
    # mkdir $PERSONAL_OUTPUT_PATH'/connectome'
    # cd $PERSONAL_OUTPUT_PATH
    # mv *_connectome.csv *_meanlength.csv connectome/
done

