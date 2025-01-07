FROM gitlab/gitlab-ce:latest
COPY gitlab.rb /etc/gitlab/gitlab.rb
RUN chmod 644 /etc/gitlab/gitlab.rb
EXPOSE 80 443 22
CMD ["/assets/wrapper"]