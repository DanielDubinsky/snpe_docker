# Docker image For SNPE

Docker image for

[SNPE](https://developer.qualcomm.com/docs/snpe/setup.html) `Snapdragon Neural Processing Engine SDK` 

with caffe & adb

based on https://github.com/tgz/docker-SNPE

# Usage

To use properly, download snpe and mount it to `/root/snpe` when running docker
  
## build

```bash
	docker build -t snpe .
```

## Convert caffe model to dlc

```bash
        docker run --rm -it --network=host --privileged -v /home/ubuntu/snpe-1.43.0.2307:/root/snpe -v /dev/bus/usb:/dev/bus/usb snpe snpe-caffe-to-dlc -i /root/snpe/models/alexnet/deploy.prototxt -b /root/snpe/models/alexnet/bvlc_alexnet.caffemodel
```

## benchmark 
    
```bash
        docker run --rm -it --network=host --privileged -v /home/ubuntu/snpe-1.43.0.2307:/root/snpe -v /dev/bus/usb:/dev/bus/usb -w /root/snpe/benchmarks/ snpe python3 snpe_bench.py -c /root/snpe/models/alexnet/alexnet_sample.json -t le64_gcc4.9

```
