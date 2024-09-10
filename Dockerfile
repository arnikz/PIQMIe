FROM node:13-alpine
LABEL description="PIQMIe: Proteomics Identifications & Quantitations Data Management & Integration Service"
LABEL maintainer="Arnold Kuzniar"
LABEL email="arnold.kuzniar@gmail.com"
LABEL orcid="0000-0003-1711-7961"
LABEL version="1.1.0"

RUN apk add perl python2 py2-pip py2-setuptools libmagic py2-cairo curl sqlite jq

WORKDIR /tmp
COPY . PIQMIe
WORKDIR ./PIQMIe
RUN pip install -r requirements.txt && \
    pip list && \
    npm install && \
    mkdir -p /var/log/piqmie
WORKDIR ./data
RUN tar xvf *.tar.bz2
WORKDIR /tmp
EXPOSE 8080
ENTRYPOINT ["cherryd", "-i", "PIQMIe", "-c", "PIQMIe/config.ini"]
