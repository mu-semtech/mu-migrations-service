FROM semtech/mu-ruby-template:2.14.0
LABEL maintainer="Aad Versteden <madnificent@gmail.com>"

ENV USE_LEGACY_UTILS 'false'
ENV BATCH_SIZE 12000
ENV MINIMUM_BATCH_SIZE 100
ENV COUNT_BATCH_SIZE 10000
