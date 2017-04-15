if [[ -d "./tmp" ]]; then
    rm -rf ./tmp
fi
mkdir ./tmp
cd ./tmp

function name {
    up_name=$(echo $1 | awk '{print toupper($0)}')
    echo "GitProject(${up_name})"
}

mkdir $(name a)
for x in b c d; do
    mkdir $(name a)/$(name $x)
done
for x in e f g; do
    mkdir $(name a)/$(name b)/$(name $x)
done
for x in h; do
    mkdir $(name a)/$(name c)/$(name $x)
done
for x in i j; do
    mkdir $(name a)/$(name d)/$(name $x)
done
tree $(name a) -A |head -n 10 > ../tree.txt
rm -rf tmp
