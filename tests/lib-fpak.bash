#!/bin/bash
# shellcheck disable=SC1090,SC2155 # source files, declare&assign

# fpak, File PAcK, is a set of bash functions to pack a hierarchy
# of files in a simple form useful for running tests.
# fpaku unpacks the simple forms in arguments, or read from its stdin
# A very primitive "tar" or "shar"

# Just the directories and file names and contents are encoded,
# not their properties nor permissions, not special files like links, devices...

# The archive format:
# - is a succession of tokens, each representing a directory or file
# - this succession is depth first, in alphabetical order
# - archives are created by the fpak functions, extracted by the fpakc ones
#   that take as argument the archive or the root
# - tokens can be assembled into:
#   - a string, separated by semicolons ";" (fpak)
#   - one per line, thus separated by newlines (fpakl)
# - file and directory names are paths relative to the root of the hierarchy
# - "path/to/dir/" is the token representing the directory root/path/dir
#   this is only used for empty dirs, as files auto-create the dirs in their path
# - "path/to/file=contents" is the token representing a file and its contents
#   in the contents, newlines are replaced by a bar "|"
# - "path/to/file:C,L" if the token reprensenting big (length > FPAK_LEN,
#   defaulting to 16), or binary files, contents containing ; or |
#   with C and L the length and checksum computed by the cksum(1) command.
#   This token type cannot be used in unpak fonctions
# - the env var FPAK_SEPS can redefine | and ;. Default being FPAK_SEPS='|;'
#   Use control chars (e.g: ctrl-^ ctrl-_) to avoid conflicts with any text file
# - the env var FPAK_EXCLUDE can define a regexp to exclude file or dir names
#   at the top-level dir args of fpak & fpakl args via [[ =~ ]].
#   E.g, to omit dot files: FPAK_EXCLUDE='^[.]'

# Example:
### If we create a dir with 3 files
# root=/tmp/foo/bar/gee
# mkdir -p $root $root/B $root/C/D
# echo 1 >$root/A; echo 'A two' >$root/B/B; echo $'gee\nxyz' >$root/E
# echo '|' >$root/qqq
### then running "fpak $root" prints:
# A=1|;B/B=A two|;C/D/;E=gee|xyz|;qqq:2245310136,2
### re-creating the hierarchy can be made by:
# export FPAK_SEPS='^;'
# fpaku 'A=1^;B/B=A two^;C/D/;E=gee^xyz^;qqq=|^'

fpakerr(){ echo "***FPAK ERROR: $*" >&2; }

# packs contents of dirs (roots) arguments, emits a single string
fpak(){
    local seps="${FPAK_SEPS:-|;}" sep
    while read -r token; do
        echo -n "${sep}$token"
        sep="${seps:1:2}"
    done < <(fpakl "$@")
    echo
}

# same, but emit one token per line on stdout
fpakl(){
    local d
    for d in "$@"; do
        d="${d%/}"
        [[ -n "$FPAK_EXCLUDE" ]] && [[ $d =~ $FPAK_EXCLUDE ]] && continue
        [[ -d "$d" ]] || { fpakerr "non-dir root '$d'"; return 1;}
        fpakldir "$d" ""
    done
}

# recurse on directories
fpakldir(){
    local r="$1" d="$2" p="${1%/}/${2%/}" f c fc
    p="${p%/}"
    if ! [[ -d "$p" ]]; then
        c=$(fpakfile "$p")
        echo "$d$c"
        return
    fi
    while read -r f; do
        if [[ -d "$p/$f" ]]; then
            fc=$(find "$p/$f" -mindepth 1 -print -quit)
            [[ -z "$fc" ]] && { echo "$d${d:+/}$f"/; continue; }
            fpakldir "$r" "$d${d:+/}$f"
            continue
        fi
        c=$(fpakfile "$p/$f")
        echo "$d${d:+/}$f$c"
    done < <(find "${p}" -mindepth 1 -maxdepth 1 -printf %P'\n' | sort)
}

# emit the token for a file
fpakfile(){
    local f="$1" s=$(stat -c %s "$1") c l s
    if ((s > ${FPAK_LEN:-16})) ||
           grep -q "[${FPAK_SEPS:-|;}]" "$f" ||
           grep -q "[^[:print:]]" "$f"; then
        read -r c l < <(cksum <"$f")
        echo ":$c,$l"
    else
        s="${FPAK_SEPS:-|;}"
        c=$(tr '\n' "${s:0:1}" <"$f")
        echo "=$c"
    fi
}

# create files/dirs by unpacking tokens strings as arguments or input
fpaku(){
    local t
    if [[ $# == 0 ]]; then
        while read -r t; do fpakutokens "$t"; done
    else
        for t in "$@"; do fpakutokens "$t"; done
    fi
}

# parses one string argument, that can be many ;-separated tokens
fpakutokens(){
    local s="$1" ts t
    IFS=';' read -ra ts <<<"$s"
    for t in "${ts[@]}"; do
        fpakutoken "$t"
    done
}

# parses only one token
fpakutoken(){
    local t="${1%}" seps="${FPAK_SEPS:-|;}" d
    if [[ $t =~ /$ ]]; then     # dir
        mkdir -p "$t"
    elif [[ $t =~ ^((.*/)?([^/]+))=(.*)$ ]]; then #  file contents
        d="${BASH_REMATCH[2]%/}"
        [[ -n "$d" ]] && mkdir -p "$d"
        # do not use <<< that adds a terminating newline
        tr "${seps:0:1}" '\n' < <(echo -n "${BASH_REMATCH[4]}") >"${BASH_REMATCH[1]%/}"
    else                        # file checksum
        fpakerr "Bad fpaku token: '$t'"
    fi
}
