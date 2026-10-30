# pumba Chaos Testing Docker containers

## Documentation
https://github.com/alexei-led/pumba

## Example

Run these commands from the repository root.

Example application:
```bash
docker run -it --rm --name tryme alpine:3.24.3 sh -c "apk add --update iproute2 && ping www.example.com"
```

Delay network by 3s:
```bash
docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock gaiaadm/pumba:1.2.1 netem --duration 1m delay --time 3000 tryme
```

Keep the socket mount in this command. Pumba needs access to Docker to find
`tryme` and start its network helper. Without the mount, it reports
`Cannot connect to the Docker daemon at unix:///var/run/docker.sock` even when
the first command works. This also applies to Testcontainers/Docker Desktop's local
runtime: the Docker context connects your terminal to the runtime, and the
mount connects Pumba to Docker inside that runtime.

## Offline presentation

Run `.github/scripts/check_all_demos.sh --no-codex` from the repository root
while online first. It builds a client image containing `iproute2` and caches
Pumba and its nettools helper. Keep the same Docker runtime running for the talk.
Run these commands from the repository root. Use a second local container as
the ping target when internet is unavailable. Cleanup first makes a new run
work even if a previous run was interrupted:

```bash
chaos_network=$(docker network create --label testing-toolbox.pumba=presentation "toolbox-chaos-$(date +%s)-$$")
docker run -d --label testing-toolbox.pumba=presentation --name target --network "$chaos_network" --pull=never alpine:3.24.3 sleep 3600
docker run -it --rm --label testing-toolbox.pumba=presentation --name tryme --network "$chaos_network" --pull=never testing-toolbox/pumba-client:3.24.3 ping target
```

Each run uses a unique network name and stores its exact ID in `chaos_network`.
This avoids clashes with old `chaos` networks. Some Docker runtimes reject
duplicate names even when attaching by ID.

In a second terminal, use the same Docker context and apply the delay. On macOS,
the socket bind source is inside the Docker VM, so `/var/run/docker.sock` works
with Testcontainers Desktop's local runtime and Colima. Docker's `--pull=never`
covers the Pumba image; Pumba's `--pull-image=false` keeps its helper cached too.

```bash
docker run --rm --pull=never \
  --label testing-toolbox.pumba=presentation \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gaiaadm/pumba:1.2.1 netem --duration 1m \
  --tc-image ghcr.io/alexei-led/pumba-alpine-nettools:latest@sha256:bdcfacdd0c42f64cd280319d6dd5d3911f33425ce4a5168bb1b7de9570b72cd1 --pull-image=false \
  delay --time 3000 tryme
```

After stopping the ping with Ctrl+C, clean up from either terminal:

```bash
./pumba/cleanup.sh
```