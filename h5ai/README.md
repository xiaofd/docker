# h5ai

[h5ai](https://larsjung.de/h5ai/) is a modern web server index. This [docker](https://www.docker.com/) image makes it trivially easy to spin up a webserver and start sharing your files through the web.

![screenshot](https://cloud.githubusercontent.com/assets/776829/3098666/440f3ca6-e5ef-11e3-8979-36d2ac1a36a0.png)

See also the [demo directory](http://larsjung.de/h5ai/sample).

## Usage

This docker image is available as an [automated build on Docker Hub](https://index.docker.io/u/clue/h5ai/), so there's no setup required. Using this image for the first time will start a download automatically. Further runs will be immediate, as the image will be cached locally.

The recommended way to run this container looks like this:

```bash
$ docker run -it --rm -p 80:80 -v `pwd`:/var/www xiaofd/h5ai
```

You can now point your webbrowser to this URL:

```
http://localhost/
```

This is a rather common setup following docker's conventions:

* `-it` will run an interactive session that can be terminated with CTRL+C
* `--rm` will run a temporary session that will make sure to remove the container on exit
* `-v {AnyDirectory}:/var/www` will mount the given directory as the base directory for the browsable directory index
* `-p {OutsidePort}:80` will bind the webserver to the given outside port
* `xiaofd/h5ai` the name of this docker image


> Fork from clue
