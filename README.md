# kubektl
A better Kubernetes CLI

This personal project was done as way for me to learn shell scripting.
As anyone working with the Kubernetes CLI know, it is important to know your current context, and namespace.
This scripts improves on that, by:
- Caching current namespace
- Caching current resource selected
- Providing easy way to target and perform actions on any kubernetes resource
- Other miscellaneous benefits, like pretty colors :) 

# Installation
Source `kube.sh` in your profile.<br>
Edit the aliases in the script as necessary.<br>
Integrate with the kubens/kubectx utility (https://github.com/ahmetb/kubectx): input their commands in the script.

# Usage
- `kube`. Use this as a replacement to 'kubectl'.<br>
This gives the added benefit of caching your namespace (without actually modifying your active namespace), and displaying helpful context/namespace/resource.

- `kubektl` Target a kubernetes resource list and do things on its resources (e.g. describe, view logs, exec into pods) easily.<br>
Requires: Run kube get [resource] [optionally with a namespace] first to view resources you are interested in.<br>
Run kubektl with no args - executes the last 'kube get [resource]' command ran, and displays line numbers.<br>
Run kubektl with line number (e.g. kubektl 2) - selects the resource on line number 2.<br>
Some commands to try out with the resource selected: kubektl describe; kubektl yaml; kubektl json | jq; kubektl logs -f; kubektl exec; kubektl kk edit; kubektl port-forward XXXX:XXXX<br>
Also try running kube get all - then kubektl, to target different types of resources in the same namespace<br>
The resource will be remembered until you do another 'kube get [resource]'.<br>

- `kubecontext`, `kubenamespace` If you have the kubectx and kubens utility (recommended), you should use these, instead of using them directly. <br>
They function the same, while also outputting/updating active ctx/ns/resources.<br>
If you use them directly, the active resource will not be cleared/ switched.<br>

- `kubewatch` Does a watch on the last selected kubernetes resource list
- `kubereload` Clears cached information and restores to default state.
