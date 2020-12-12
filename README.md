# RasPiOS K8s

A Raspberry Pi OS arm64 image that's ready to run Kubernetes!

:construction:
:warning:
**This project is currently under construction.**
:warning:
:construction:

This project customises the new Raspberry Pi OS arm64 image so its correctly 
configured, and installs `docker`, `kubeadm`, `kubelet` and everything else
required to run Kubernetes on a Raspberry Pi.

## Usage

### 1. Write

Download the latest image from the [GitHub releases
page](https://github.com/wwwil/raspios-k8s/releases) or [build it
yourself](#Build). Then write the image to a micro SD card using a tool like
[Etcher](https://www.balena.io/etcher/) or the `dd` command. Put the micro SD
card into a Raspberry Pi and boot it up.

### 2. Connect

Once the Raspberry Pi has booted up you can then connect to it using SSH:

```
ssh pi@raspios-k8s.local
```

### 3. Run

You can then use `kubeadm` to create a cluster:

```bash
sudo kubeadm init
```

## Build

The image is built in Docker using [Skydock](https://github.com/wwwil/skydock)
to run a [setup script](./setup.sh) to configure the OS and install the required
packages. This can be run by the [build script](./build.sh) which will download
and extract the base Raspberry Pi OS image.

```
./build
```

## Roadmap

Items to do:

- Switch container runtime from Docker to Cri-o
- Fetch images for kubeadm in setup.sh
- Set up HA control plane
- Establish procedure for joining nodes
- Add more boot automation
