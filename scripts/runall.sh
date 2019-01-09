outputprefix=$1
if [[ "$outputprefix" == "tokenize" || "$outputprefix" == "mwt" || "$outputprefix" == "lemma" ]]; then
    outputprefix=""
else
    shift
fi
module=$1
shift
args=$@

n_gpus=`gpustat | tail -n+2 | wc -l`

i=0
free_gpus=""
for free in `gpustat | tail -n+2 | cut -d"|" -f3 | awk '{print $3-$1}'`; do
    if [ $free -ge 10000 ]; then
        free_gpus=$free_gpus","$i
    fi
    i=$((i+1))
done

i=0
tbs=`wc -l ${module}_test_treebanks`
for tb in `cat ${module}_test_treebanks`; do
    while [[ $free_gpus != *"$((i % n_gpus))"* ]]; do
        i=$((i+1))
    done
    if [[ "$outputprefix" == "" ]]; then
        scripts/run_${module}.sh $tb $((i % n_gpus)) $args &
    else
        scripts/run_${module}.sh $outputprefix $tb $((i % n_gpus)) $args &
    fi
    pids[${i}]=$!
    i=$((i+1))
done

# wait for all pids
for pid in ${pids[*]}; do
    wait $pid
done

for t in `cat ${module}_test_treebanks | xargs -i bash scripts/treebank_to_shorthand.sh ud {}`; do
    if [[ $module = "tokenize" ]]; then
        echo `cat data/tokenize/${t}.results | grep -v '^--' | awk '{if ($1 == 0 || $2 == 0 || $3 == 0) print 0; else print (2.01/(1/$1+1/$2+.01/$3))}' | tail -1 `;
    else
        echo `cat data/${module}/${t}.results | grep -v '^--' | awk '{print $1}' | tail -1 `;
    fi
done | awk '{total = total + $1; count = count + 1}END{print total/count}' >&2