# Use the official Jekyll image
FROM jekyll/jekyll:3.8.3

RUN apk add --no-cache nginx supervisor

COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set the working directory inside the container
WORKDIR /srv/jekyll

# Copy your site source files into the image
COPY . .

# Build the static site
RUN jekyll build

# Expose HTTP port
EXPOSE 80

CMD ["/usr/bin/supervisord", "-n"]