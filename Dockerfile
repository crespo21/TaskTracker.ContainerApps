# Use the official .NET 9.0 runtime as the base image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

# Use the .NET 9.0 SDK for building the application
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["TasksTracker.TasksManager.Backend.Api.csproj", "."]
RUN dotnet restore "TasksTracker.TasksManager.Backend.Api.csproj"

# Copy the rest of the application code
COPY . .

# Build the application
RUN dotnet build "TasksTracker.TasksManager.Backend.Api.csproj" -c Release -o /app/build

# Publish the application
FROM build AS publish
RUN dotnet publish "TasksTracker.TasksManager.Backend.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Create the final runtime image
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "TasksTracker.TasksManager.Backend.Api.dll"]
