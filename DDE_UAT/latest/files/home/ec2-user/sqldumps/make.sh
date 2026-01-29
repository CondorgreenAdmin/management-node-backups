p=$(ls -1 dl*.csv | egrep -v csv.data.csv)
echo "P=$p"
read junk
for i in $p; 
do 
    FNAM="load_$i.sql"
echo "FNAM= $FNAM"
	echo "begin work;" > $FNAM; 
	echo "load from \"./$i.data.csv\" DELIMITER \",\"" >> $FNAM
	echo -n "insert into " >> $FNAM
	nam=$(echo "${i%.*}")
	echo -n "$nam(" >> $FNAM
	cat $i.header >> $FNAM
	echo ");" >> $FNAM
    echo "commit work;" >> $FNAM
done
