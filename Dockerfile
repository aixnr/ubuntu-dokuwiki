FROM ubuntu:20.04
COPY scripts/install.sh /
RUN bash /install.sh
RUN rm /install.sh
COPY entrypoint.sh /
ENTRYPOINT ["bash", "entrypoint.sh"]
CMD ["monit"]

