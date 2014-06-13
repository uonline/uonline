FROM base/archlinux
MAINTAINER m1kc <m1kc@yandex.ru>

# Add sources
ADD . /uonline
WORKDIR /uonline

# Add node & coffee
RUN pacman -Sy
RUN pacman -S --noconfirm nodejs
RUN npm install -g coffee-script

# What to run
CMD ["./main.coffee"]
EXPOSE 5000
