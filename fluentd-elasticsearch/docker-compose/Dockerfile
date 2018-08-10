FROM devops-reg.io/public/elasticsearch-oss:6.2.4

MAINTAINER cookeem@qq.com

ADD search-guard-6-6.2.4-22.1.zip /usr/share/elasticsearch/

RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b file:///usr/share/elasticsearch/search-guard-6-6.2.4-22.1.zip

RUN rm -rf search-guard-6-6.2.4-22.1.zip

# 构建镜像
# docker build -t 'devops-reg.io/public/elasticsearch-guard:6.2.4' .

