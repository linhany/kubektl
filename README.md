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
Source `kube.sh` in your profile.
Edit the aliases in the script as necessary.
Integrate with the kubens/kubectx utility (https://github.com/ahmetb/kubectx): input their commands in the script.
