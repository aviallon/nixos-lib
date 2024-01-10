{ lib
, writeText
}:

writeText "pipewire-airplay.conf"  ''
# Noise canceling source
#
# start with pipewire -c filter-chain/source-rnnoise.conf
#
context.properties = {
    log.level        = 3
}

#context.spa-libs = {
#    audio.convert.* = audioconvert/libspa-audioconvert
#    support.*       = support/libspa-support
#}

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

    {   name = libpipewire-raop-discover
        args = {
            #raop.latency.ms = 1000
            stream.rules = [
                {   matches = [
                        {    raop.ip = "~.*"
                             #raop.port = 1000
                             #raop.name = ""
                             #raop.hostname = ""
                             #raop.domain = ""
                             #raop.device = ""
                             #raop.transport = "udp" | "tcp"
                             #raop.encryption.type = "RSA" | "auth_setup" | "none"
                             #raop.audio.codec = "PCM" | "ALAC" | "AAC" | "AAC-ELD"
                             #audio.channels = 2
                             #audio.format = "S16" | "S24" | "S32"
                             #audio.rate = 44100
                             #device.model = ""
                        }
                    ]
                    actions = {
                        create-stream = {
                            #raop.password = ""
                            stream.props = {
                                #target.object = ""
                                media.class = "Audio/Sink"
                            }
                        }
                    }
                }
            ] # stream.rules
        } # args
    }
}]''
