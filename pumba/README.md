# pumba Chaos Testing Docker containers

## Documentation
https://github.com/alexei-led/pumba

## Example

Example application:
```bash
docker run -it --rm --name tryme alpine sh -c "apk add --update iproute2 && ping www.example.com" 
```

Delay network by 3s:
```bash
docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock gaiaadm/pumba netem --duration 1m delay --time 3000 tryme
```