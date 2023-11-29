#!/bin/bash
rm -f new_block.properties id_map.txt

echo "# Automatically generated.
# Do not edit unless you know what you are doing.
# Block ID values may change with any minecraft update.
# The only stable block ID is 35917 for modded lights.

# Add your modded light sources here:
block.35917=
" > new_block.properties
blockidmappings=$(cat $1 | sed 's/#.*$//' | sed '/layer\..*$/d' | tr ' ' '@')
declare -A mappings
allblocks=""
for mapping in ${blockidmappings}
do
    blockid=$(echo ${mapping} | sed 's/^block.\([0-9]*\)=.*$/\1/')
    blocks=$(echo ${mapping} | tr '@' ' ' | sed 's/^block.[0-9]*=//')
    for block in ${blocks}
    do
        allblocks="${allblocks}
${block}"
        mappings["${block}"]=${blockid}
    done
done
allblocks="$(echo "${allblocks}" | sort -u)"
blockstates="$(cat $2)"
new_id=1
for blockstate in ${blockstates}
do
    baseblock=$(echo "${blockstate}" | sed 's/:.*$//')
    attributes=$(echo "${blockstate}" | sed 's/^[^:]*//' | tr ':' '\n')
    relatedblocks=$(echo "${allblocks}" | grep -e "^${baseblock}:")
    relatedblocks="${relatedblocks} $(echo "${allblocks}" | grep -e "^${baseblock}$")"
    unset relatedids
    declare -a relatedids
    for relatedblock in ${relatedblocks}
    do
        otherattributes=$(echo ${relatedblock} | tr ':' '\n' | sed '1d')
        matches="true"
        missingattributes=" NONE"
        for attribute in ${otherattributes}
        do
            iscontained="false"
            for _ in $(echo "${attributes}" | grep -e "${attribute}")
            do
                iscontained="true"
            done
            if [ ${iscontained} == "false" ]
            then
                attrkey=$(echo ${attribute} | sed 's/=.*//')
                for _ in $(echo "${attributes}" | grep -e "${attrkey}")
                do
                    matches="false"
                done
                if [ ${matches} == "false" ]
                then
                    break
                fi
                missingattributes="${missingattributes}:${attribute}"
            fi
        done
        if [ ${matches} == "true" ]
        then
            relatedids[${mappings[${relatedblock}]}]="${relatedids[${mappings[${relatedblock}]}]}${missingattributes}"
        fi
    done
    printf "\r                                                       \r%s\t%s\r" "${baseblock}" "${!relatedids[*]}"
    if [ "${!relatedids[*]}" == "" ]
    then
        relatedids[0]="NONE"
    fi
    for id in ${!relatedids[*]}
    do
        printstr="block.${new_id}="
        printedsomething="false"
        for missingattributes in ${relatedids[$id]}
        do
            printstr="${printstr}${blockstate}${missingattributes} "
            printedsomething="true"
        done
        if [ printedsomething == "false" ]
        then
            printstr="${printstr}${blockstate} "
        fi
        echo ${printstr} | sed 's/NONE//g' >> new_block.properties
        echo "${new_id}:${id}" >> id_map.txt
        new_id=$(( new_id+1 ))
    done
done
for block in $(echo ${allblocks} | sed 's/:.*$//' | sort -u)
do
    searchresult=$(grep new_block.properties -e "[= ]$block[^a-z_]")
    empty="no"
    for result in $searchresult
    do
        empty="yes"
    done
    if [ $empty == "no" ]
    then echo "$block"
    fi
done
