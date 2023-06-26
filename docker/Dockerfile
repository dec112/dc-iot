FROM oydeu/dc-base
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		nodejs \
		cron \
		curl

COPY Gemfile.extend $WORKDIR
RUN git config --global url."https://".insteadOf git:// && \
	bundle install && \
	bundle update

COPY . .
RUN bundle install

CMD ["./script/init.sh"]
EXPOSE 3000
