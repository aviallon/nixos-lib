{ lib
, writeText
, rnnoise-plugin
, noiseFilterStrength
}:

writeText "pipewire-noise-filter.conf"  ''
# Noise canceling source
#
# start with pipewire -c filter-chain/source-rnnoise.conf
#
context.properties = {
    log.level        = 3
}

context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}

context.modules = [
    {   name = libpipewire-module-rtkit
        args = {
            nice.level   = -11
        }
        flags = [ ifexists nofail ]
    }
    {   name = libpipewire-module-protocol-native }
    {   name = libpipewire-module-client-node }
    {   name = libpipewire-module-adapter }

    {   name = libpipewire-module-filter-chain
        args = {
            node.name =  "rnnoise_source"
            node.description =  "Noise Canceling source"
            media.name =  "Noise Canceling source"
            filter.graph = {
                nodes = [
                    {
                        type = ladspa
                        name = rnnoise
                        plugin = ${rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so
                        label = noise_suppressor_stereo
                        control = {
                            "VAD Threshold (%)" = ${toString noiseFilterStrength}
                            "VAD Grace Period (ms)" = 200
                            "Retroactive VAD Grace (ms)" = 0
                        }
                    }
                ]
            }
            capture.props = {
                node.name =  "capture.rnnoise_source"
                node.passive = true
                audio.rate = 48000
            }
            playback.props = {
                node.name = "rnnoise_source.output"
                media.class = Audio/Source
                node.virtual = false
                audio.rate = 48000
            }
        }
    }
]''
