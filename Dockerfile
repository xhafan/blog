# Use the official Jekyll image
FROM jekyll/jekyll:3.8.3

# Set the working directory inside the container
WORKDIR /srv/jekyll

# Copy your site source files into the image
COPY . .

# Build the static site
RUN jekyll build

# Expose the default Jekyll HTTP port
EXPOSE 4000

# Run Jekyll serve
CMD ["jekyll", "serve", "--host", "0.0.0.0"]