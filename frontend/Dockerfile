FROM node:18

WORKDIR /app

# Copy package.json and install dependencies
COPY package.json package-lock.json* ./
RUN npm install

# Ensure react-scripts is installed globally (fix for missing)
RUN npm install -g react-scripts

# Copy the rest of the app
COPY ./src ./src

EXPOSE 3000
CMD ["npm", "start"]
