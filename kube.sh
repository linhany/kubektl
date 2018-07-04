# kubektl: A better kubernetes cli

# [kube]. Use this as a replacement to 'kubectl'.
# This gives the added benefit of caching your namespace (without actually modifying your active namespace), and displaying helpful context/namespace/resource.

# [kubektl] Target a kubernetes resource list and do things on its resources (e.g. describe, view logs, exec into pods) easily.
# Requires: Run kube get [resource] [optionally with a namespace] first to view resources you are interested in.
# Run kubektl with no args - executes the last 'kube get [resource]' command ran, and displays line numbers.
# Run kubektl with line number (e.g. kubektl 2) - selects the resource on line number 2.
# Some commands to try out with the resource selected: kubektl describe; kubektl yaml; kubektl json | jq; kubektl logs -f; kubektl exec; kubektl kk edit; kubektl port-forward XXXX:XXXX
# Also try running kube get all - then kubektl, to target different types of resources in the same namespace
# The resource will be remembered until you do another 'kube get [resource]'.

# [kubecontext, kubenamespace] If you have the kubectx and kubens utility (recommended), you should use these, instead of using them directly. 
# They function the same, while also outputting/updating active ctx/ns/resources.
# If you use them directly, the active resource will not be cleared, which leads to inconsistency.

# [kubewatch] Does a watch on the last selected kubernetes resource list
# [kubereload] Clears cached information and restores to default state.

## CHOOSE YOUR COLORS ##
CTX_COLOR='\033[31m' # red
NS_COLOR='\033[33m' # orange
RESOURCE_COLOR='\033[32m' # green
CMD_COLOR='\033[34m' # blue
LINE_SELECT_COLOR='0;32' # for line selection: green

## IF YOU HAVE KUBENS/KUBECTX, INPUT IT HERE ##
KUBECTX_CMD='kctx'
KUBENS_CMD='kns'

## RECOMMENDED: USE ALIASES TO SHORTEN THE COMMANDS ##
alias k=kube
alias kk=kubektl
alias kr=kubereload
alias kw=kubewatch
alias kc=kubecontext
alias kn=kubenamespace
alias kvar=kubevar

kube() {
  local args="$@"
  local ctx=$(kubectl config current-context)

  if [ -z "$args" ]; then
    if [ -z "$__K_NS" ]; then
      __export_namespace_from_defaults
    fi
    __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE"
    return
  fi

  local cmd="kubectl $args"
  local ns=$(echo "$args" | egrep -o '\-n\s+\S+|--all-namespaces' | sed s/\-n\s+//)

  if [ ! -z "$ns" ]; then
    export __K_NS=$ns
  elif [ ! -z "$__K_NS" ]; then
    cmd="kubectl $__K_NS $@"
  else
    __export_namespace_from_defaults
    cmd="kubectl $__K_NS $@"
  fi
  # check for a k get [type] [namespace] request
  if egrep '\sget\s' <<< $cmd >/dev/null; then
    local output=$(eval "$cmd") 2>&1 # for some reason, sometimes newlines get outputted into stderr. this workaround hides 'get' errors however.
    if [ ! -z "$output" ]; then
      export __K_TYPE=$(echo "$args" | egrep -o 'get\s+\S+' | tr -d " " | sed "s/^get//")
      export __K_RESOURCE=''
      export __K_TYPE_ALL=false
      export __K_ALL_NAMESPACES=false
      if [[ "$__K_TYPE" == "all" ]]; then
        export __K_TYPE_ALL=true
      fi
      if [[ "$__K_NS" == "--all-namespaces" ]]; then
        export __K_ALL_NAMESPACES=true
      fi
      __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
      echo "$output"
    fi
  else
    __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
    eval $cmd
  fi
}

kubektl() {
  if [ -z "$__K_NS" ] || [ -z "$__K_TYPE" ] ; then
    return
  fi

  local cmd="kubectl $__K_NS get $__K_TYPE"
  local args="$@"
  local ctx=$(kubectl config current-context)

  # no args: print line numbers with the last get operation
  if [ -z "$args" ]; then
    __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
    local output=$(eval "$cmd --no-headers" | grep -n "")
    if [ -z "$__K_RESOURCE" ]; then
      echo "$output"
    else
      if [[ "$__K_TYPE_ALL" == "true" ]] && [[ "$__K_ALL_NAMESPACES" == "true" ]]; then
        local ns=$(echo "$__K_NS" | tr -d " " | sed s/\-n//)
        echo "$output" | GREP_COLOR=$LINE_SELECT_COLOR egrep --color=always "[0-9]+:${ns}\s+${__K_TYPE}/${__K_RESOURCE}\s+.*|$"
      elif [[ "$__K_TYPE_ALL" == "true" ]]; then
        echo "$output" | GREP_COLOR=$LINE_SELECT_COLOR egrep --color=always "[0-9]+:${__K_TYPE}/${__K_RESOURCE}\s+.*|$"
      elif [[ "$__K_ALL_NAMESPACES" == "true" ]]; then
        local ns=$(echo "$__K_NS" | tr -d " " | sed s/\-n//)
        echo "$output" | GREP_COLOR=$LINE_SELECT_COLOR egrep --color=always "[0-9]+:${ns}\s+${__K_RESOURCE}\s+.*|$"
      else
        echo "$output" | GREP_COLOR=$LINE_SELECT_COLOR egrep --color=always "[0-9]+:${__K_RESOURCE}\s+.*|$"
      fi
    fi
    return
  fi 

  # args contains a num: mark that resource as active
  # num should be first argument if present.
  local line=$(echo "$args" | awk '{print $1}')
  if [[ $line =~ ^[0-9]+$ ]] && [ ! -z "$__K_TYPE" ]; then
    local resource
    local output=$(eval "$cmd --no-headers" | grep -n "")
    resource=$(echo "$output" | sed -n ${line}p)
    if [ $line -eq 0 ] || [ -z "$resource" ]; then
      __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
      echo "error: that line does not exist"
      return 1
    fi
    if [[ "$__K_ALL_NAMESPACES" == "true" ]]; then
      export __K_NS="-n $(echo $resource | awk '{print $1}' | sed s/.\*://)"
      resource=$(echo $resource | awk '{print $2}')
    else
      resource=$(echo $resource | awk '{print $1}' | sed s/.\*://)
    fi
    # handle case of type 'all'
    if [[ "$__K_TYPE_ALL" == "true" ]]; then
      export __K_TYPE=$(echo $resource | sed "s/\/.*$//")
      export __K_RESOURCE=$(echo $resource | sed "s/^.*\///")
    else
      export __K_RESOURCE=$resource
    fi
    args=$(echo "$args" | sed "s/$line//" | awk '{sub(/^ */,"",$0);sub(/ *$/,"",$0)}1')
    if [ -z "$args" ]; then
      __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
      return
    fi
  fi
  
  # other args: run commands on active resource
  if [ ! -z "$__K_RESOURCE" ] && [ ! -z "$__K_TYPE" ] && [ ! -z "$__K_NS" ]; then
    if grep 'log' <<< "$args" >/dev/null; then
      cmd="kubectl $__K_NS $args $__K_RESOURCE"
    elif grep 'exec' <<< "$args" >/dev/null; then
      cmd="kubectl $__K_NS $args -it $__K_RESOURCE /bin/bash"
    elif egrep '^yaml|json|wide$' <<< "$args" >/dev/null; then
      cmd="kubectl $__K_NS get $__K_TYPE $__K_RESOURCE -o $args"
    elif grep 'port-forward' <<< "$args" >/dev/null; then
      args=$(echo "$args" | tr -d " " | sed "s/port-forward//")
      cmd="kubectl $__K_NS port-forward $__K_RESOURCE $args"
    else
      cmd="kubectl $__K_NS $args $__K_TYPE $__K_RESOURCE"
    fi
    __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
    eval $cmd
  fi
}

kubewatch() {
  if [ -z "$__K_NS" ] || [ -z "$__K_TYPE" ] ; then
    return
  fi

  local cmd="watch -n 1 kubectl $__K_NS get $__K_TYPE"
  local ctx=$(kubectl config current-context)
  __show "$ctx" "$__K_NS" "$__K_TYPE/$__K_RESOURCE" "$cmd"
  eval "$cmd"
}

kubereload() {
  local ctx=$(kubectl config current-context)
  export __K_TYPE=''
  export __K_RESOURCE=''
  export __K_TYPE_ALL=false
  export __K_ALL_NAMESPACES=false
  __export_namespace_from_defaults
  __show "$ctx" "$__K_NS" "$KTYPE/$__K_RESOURCE" 
}

kubecontext() {
  eval "$KUBECTX_CMD $@"
  kubereload
}

kubenamespace() {
  eval "$KUBENS_CMD $@"
  kubereload
}

kubevar() {
  printenv | grep __K_
}

### Private helper funcs/vars ###
NC='\033[0m' # no color - to reset

__show() {
  local ctx=$1
  local ns=$2
  local resource=$3
  local cmd=$4
  if [ ! -z "$cmd" ]; then
    echo -e "[$CTX_COLOR$ctx$NC][$NS_COLOR$ns$NC][$RESOURCE_COLOR$resource$NC] ($CMD_COLOR$cmd$NC)" 1>&2
  else
    echo -e "[$CTX_COLOR$ctx$NC][$NS_COLOR$ns$NC][$RESOURCE_COLOR$resource$NC]" 1>&2
  fi
}
__export_namespace_from_defaults() {
  local ns="$(kubectl config view -o=jsonpath="{.contexts[?(@.name==\"${ctx}\")].context.namespace}")"
  if [ -z "$ns" ]; then
    ns="-n default"
  else
    ns="-n $ns"
  fi
  export __K_NS=$ns
}
