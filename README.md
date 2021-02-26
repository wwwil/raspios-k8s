# RasPiOS K8s

A Raspberry Pi OS arm64 image that's ready to run Kubernetes!

:construction:
:warning:
**This project is currently under construction.**
:warning:
:construction:

This project customises the new Raspberry Pi OS arm64 image so its correctly 
configured, and installs `containerd`, `kubeadm`, `kubelet` and everything else
required to run Kubernetes on a Raspberry Pi.

## Usage

### 1. Write

Download the latest image from the [GitHub releases
page](https://github.com/wwwil/raspios-k8s/releases) or [build it
yourself](#Build). Then write the image to an SD card using a tool like
[Etcher](https://www.balena.io/etcher/) or `dd`.

### 2. Configure

#### SSH

SSH password login is disabled in the RasPi OS K8s images. To connect, copy your
SSH public key onto the `FAT` formatted `boot` partition of the SD card:

```bash
cp ~/.ssh/id_rsa.pub /Volumes/boot/
```

It will be moved to `/home/pi/.ssh` on boot.

#### Hostname

The hostname can be set by writing it to a `hostname` file in the `boot`
partition.

```bash
echo "raspios-k8s-worker-01" > /Volumes/boot/hostname
```

This will be read and set on boot. The default hostname is `raspios-k8s`.

### 3. Connect

Put the SD card into a Raspberry Pi, boot it up and connect to it using SSH. The
hostname set in the previous step can be used, for example:

```
ssh pi@raspios-k8s-worker-01.local
```

### 4. Run

You can then use `kubeadm` to create a cluster. Edit the example configuration
file on the Raspberry Pi at `/home/pi/kubeadm.yaml`, then run:

```bash
sudo kubeadm init --config /home/pi/kubeadm.yaml
```

To join an existing cluster get a join token from one of the current nodes:

```bash
kubeadm token create --print-join-command
```

Then run the displayed command on the new Raspberry Pi.

See the [`kubeadm`
documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) for
more details.

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

- Set up HA control plane
- Add more boot automation
  - Run kubeadm init or join if `/boot/kubeadm.yaml` present
