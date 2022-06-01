FROM docker.io/maven:3-jdk-8 AS build

COPY . /usr/src/mymaven
RUN cd /usr/src/mymaven && mvn clean install

FROM docker.io/openjdk:8-jre

COPY --from=build /usr/src/mymaven/target /target
WORKDIR /target
CMD ["java", "-jar", "rabbitmq-tutorials.jar"]