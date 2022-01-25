FROM gitpod/workspace-full

RUN sudo apt-get update \
 && sudo apt-get install -y doxygen \
 && sudo apt-get install -y graphviz \
 && sudo rm -rf /var/lib/apt/lists/*
