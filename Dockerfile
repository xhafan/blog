# Use the official Jekyll image
FROM jekyll/jekyll:3.8.3

# Set the working directory inside the container
WORKDIR /srv/jekyll

# Copy only the files that affect gem installation
COPY Gemfile ./

# Install Ruby gems (this will be cached unless Gemfile changes)
RUN bundle install
                    
RUN apk add --no-cache nginx supervisor

COPY nginx.conf /etc/nginx/
COPY supervisord.conf /etc/supervisor/conf.d/

# Create Nginx run directory
RUN mkdir -p /run/nginx \
    && chown -R root:root /run/nginx

# Copy your site source files into the image
COPY . .

# Build the static site
RUN jekyll build

# Expose HTTP port
EXPOSE 80

CMD ["/usr/bin/supervisord", "-n"]