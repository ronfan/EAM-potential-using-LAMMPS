#!/bin/bash

#SBATCH --comment=Test

# #SBATCH --nodes=2
#SBATCH --ntasks=32
# #SBATCH --tasks-per-node=128
#SBATCH --account=ec215
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1

#SBATCH --partition=standard
#SBATCH --qos=lowpriority
# #SBATCH --partition=serial
# #SBATCH --qos=serial


LAMMPROOT=/work/ec215/ec215/s1921711/PROGRAMS/mylammps/src/lmp_mpi

module load lammps 
error_exit()
{
    echo "Error: $1"
    exit 1
}

for L in 2.8
do

lattice_spacing=$L


outdir=OUTFOLDER/EAM_melting_nvt_Dummy_animation_run2_with_right_vacumm${lattice_spacing}


if [ ! -e ${outdir}/DATA.txt ];then
    
    echo "Sedding to a spacing of ${lattice_spacing}"
    
    sed "s/XXXXX/${lattice_spacing}/" template_Li_solid.lammps > Li_solid.lammps
    sed "s/XXXXX/${lattice_spacing}/" template_Li_liquid.lammps > Li_liquid.lammps
    sed "s/XXXXX/${lattice_spacing}/" template_vac1.lammps > vac1.lammps
    sed "s/XXXXX/${lattice_spacing}/" template_vac2.lammps > vac2.lammps
    sed "s/XXXXX/${lattice_spacing}/" template_Li_exper.lammps > Li_exper.lammps
    
    srun lmp_mpi -in Li_solid.lammps |& tee log_solid.output 

    wait
    # 
    srun lmp_mpi -in Li_liquid.lammps |& tee log_liquid.output 
    
    wait
    
    srun lmp_mpi -in vac1.lammps |& tee dummy.output

    wait
    
    srun lmp_mpi -in vac2.lammps |& tee dummy.output 
    
    wait
    
    srun lmp_mpi -in Li_exper.lammps |& tee log_exper.output
    
    # Wait for all background jobs to finish
    wait



    
    ################################# TIDY UP
    # Calculation is done, next few lines simply tidy up the output files and put them all in the folder $outdir
    
    mkdir -p $outdir
    for f in log_exper.output log_solid.output log_liquid.output data* *.lammps *.lammpstrj;do
	cp -v $f ${outdir}
    done
    
    max=0
    for file in slurm*.out;do
	fnum=$(echo $file | awk '{print $NF}' FS=- | awk '{print $1}' FS=.o)
	(( fnum > max )) && max=${fnum}
    done
    cp -v slurm-${max}.out ${outdir}
    
    
    # Make handy data-file
    startline=$(grep -n -m 1 '   Step          Time' log_exper.output)
    lala=$(echo $startline | awk '{print $1}' FS=:)
    slinenum=$((lala+1))
    endline=$(grep -n -m 1 'Loop time of ' log_exper.output)
    lala=$(echo $endline | awk '{print $1}' FS=:)
    elinenum=$((lala-1))
    echo "linenums = ${slinenum}  ${elinenum}"
    echo "# ${startline}" > DATA.txt
    sed -n "${slinenum},${elinenum}p" log_exper.output >> DATA.txt
    cp -v DATA.txt ${outdir}
    
    
else
    echo "
Skip	 ping ${outdir} as ${outdir}/DATA_$L_.txt exists!
"	 
fi


echo "Success!!"

wait

done
