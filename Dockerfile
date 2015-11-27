
###
### build via:
###   docker build -t distribot/dev -f Dockerfile .
###
### run via:
###   docker run -t -i -p 15672 distribot/dev /bin/bash
###

FROM ubuntu:14.04
RUN useradd -d /home/ubuntu -m -s /bin/bash ubuntu
ADD ./ /var/www/distribot
RUN echo "ubuntu:changeme" | chpasswd
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN sed -i s#/home/ubuntu:/bin/false#/home/ubuntu:/bin/bash# /etc/passwd
USER ubuntu
WORKDIR /var/www/distribot
#RUN provision_vm.sh
