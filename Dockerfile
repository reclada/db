FROM postgres

RUN apt-get update
RUN apt-get -y install python3 postgresql-plpython3-13 python3-pip
RUN pip3 install -U pip wheel
RUN pip3 install requests pyjwt[crypto] oic
