# Bash completion for gsconnect
# Install: source this file in ~/.bashrc, or copy to /etc/bash_completion.d/gsconnect

_gsconnect_devices_names() {
    gsconnect --list 2>/dev/null | awk 'NR>2 && $1 != "" {print $2}'
}

_gsconnect_devices_ids() {
    gsconnect --list 2>/dev/null | awk 'NR>2 && $1 != "" {print $1}'
}

_gclip_completion() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --name)
            COMPREPLY=( $(compgen -W "$(_gsconnect_devices_names)" -- "$cur") )
            return 0
            ;;
        --id)
            COMPREPLY=( $(compgen -W "$(_gsconnect_devices_ids)" -- "$cur") )
            return 0
            ;;
    esac

    local opts="--list --name --id --push --pull --help"
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

complete -F _gclip_completion gclip
