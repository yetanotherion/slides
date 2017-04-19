make
DIRNAME=jenkins_meetup_murex_19_04_2017
DIR_IN_TMP="/tmp/${DIRNAME}"
DIR_IN_MOAB="/var/opt/moab/slides"

ssh moab "if [[ ! -d ${DIR_IN_TMP} ]]; then mkdir ${DIR_IN_TMP}; fi"
scp -r imgs slides.html moab:${DIR_IN_TMP}/
ssh moab "rm -r ${DIR_IN_MOAB}/${DIRNAME}"
ssh moab "mv -f ${DIR_IN_TMP} ${DIR_IN_MOAB}/"
