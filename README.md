OFuzz?
======

OFuzz is a fuzzing platform written in OCaml. OFuzz currently focuses on
file-processing applications that run on *nix platforms. The main design
principle of OFuzz is flexibility: it must be easy to add/replace fuzzing
components (crash triaging module, test case generator, etc.) or algorithms
(mutation algorithms, scheduling algorithms).

OFuzz provides a rich set of APIs to develop new mutation algorithms, crash
triaging algorithms, and also configuration scheduling algorithms. For example,
implementing a new mutation algorithm is as easy as writing a single OCaml file
that contains a function of a certain type thanks to OCaml's module system.
Implementing a crash triaging algorithm is equivalent to implementing a single
OCaml module.

We observed that previous fuzzers have their own sampling algorithms that are
hard to be modeled using a closed-form expression. Thus, the motivation of OFuzz
is to introduce a mutational fuzzing framework that provides mutation algorithms
based on formal statistical sampling processes. The design of OFuzz should
enable security researchers to design their own algorithms, and test them. Our
goal is to encourage formal study in fuzzing.

Currently, OFuzz supports four different bit-flipping mutation algorithms. OFuzz
supports not only mathematical algorithms, but also one of the practical fuzzing
algorithms derived from zzuf (http://caca.zoy.org/wiki/zzuf), which essentially
divides an input seed into multiple chunks and applies bit-flipping algorithm
for each chunk. See [Mutation Algorithms](docs/Mutation.md) for more details
about the mutation algorithms of OFuzz.

Installation?
=============

Make sure you installed the following dependencies for compilation.

- With OPAM (Linux & Mac OS X)

    We recommend using OPAM (http://opam.ocamlpro.com/).

   ```bash
   opam install ocamlfind yojson camlidl mysql camlbz2 batteries curses
   ```

- Without OPAM (Debian, Ubuntu)

    If you prefer not to use OPAM, you can also use OS-specific packages. For
    example, in Debian:

   ```bash
   sudo apt-get install build-essential \
        ocaml libfindlib-ocaml-dev camlidl \
        libgmp-dev libmpfr-dev libmpc-dev \
        libboost-dev libboost-filesystem-dev \
        libbatteries-ocaml-dev libyojson-ocaml-dev \
        libmysql-ocaml-dev libbz2-ocaml-dev libncurses5-dev
   ```

Once you have installed all the necessary packages, simply run:

    make

To run OFuzz, one needs the followings.

- GDB (with Python support: must be compiled with --with-python) or LLDB
- Xvfb (optional, for fuzzing GUI applications remotely)
- X11vnc (option, for fuzzing GUI applications remotely)


Intalling OFuzz from a binary distribution
==========================================

A binary distribution requires several libraries to run properly.

- Debian / Ubuntu

   ```bash
   sudo apt-get install -y --force-yes \
        libboost-filesystem1.49.0 libmysqlclient18 xvfb x11vnc gdb screen
   ```

Running OFuzz
=============

Suppose we are fuzzing a program *FFMpeg* with a seed file called "seed.mp4". We
can run OFuzz in two steps as follows. See the [wiki](Wiki.md) page for more
usage help.

   1. Create an OFuzz configuration file (ffmpeg.conf) as follows. Please refer
      to our wiki page for further information about OFuzz configuration file.
   ```json
   [
     {
       "cmds" : ["/usr/bin/ffmpeg", "-i", "SEED.mp4", "foo.avi"],
       "filearg" : 2,
       "mratiostart" : 0.001,
       "seedfile" : "/path/to/seed.mp4"
     }
   ]
   ```
   A conf file needs to contain at least four entries: (1) **cmds** specifies
   the command line arguments for executing *FFmpeg*; (2) **filearg** specifies
   which argument in the **cmds** is the seed file. If it is 2, that means the
   3rd argument is the seed; (3) **mratiostart** specifies a mutation ratio for
   mutating the seed; (4) **seedfile** is a path to the seed file.

   2. Run OFuzz!
   ```bash
   ./ofuzz ./ffmpeg.conf
   ```

See the [wiki](Wiki.md) page for more usage help.

Release Notes
=============

See [Release Notes](ReleaseNotes.md).
