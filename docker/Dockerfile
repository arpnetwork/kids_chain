FROM erlang:20.3.6-alpine

# distillery & kchain deps
RUN apk add --no-cache bash libstdc++

ENV APP_ROOT /opt/app
ENV CODE_LOADING_MODE interactive

ADD *.tar.gz $APP_ROOT
ADD kchain $APP_ROOT/bin/

WORKDIR $APP_ROOT

# mnesia dir
ENV REPLACE_OS_VARS true
ENV KC_DATA_DIR $APP_ROOT/data
VOLUME $KC_DATA_DIR

EXPOSE 3000

CMD $APP_ROOT/bin/kids_chain foreground
