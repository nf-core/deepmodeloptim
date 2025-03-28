/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { STIMULUS_SPLIT_SPLIT } from '../../../modules/local/stimulus/split_split'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SPLIT_DATA_CONFIG_SPLIT_WF {
    take:
    ch_data_config

    main:

    ch_versions = Channel.empty()

    STIMULUS_SPLIT_SPLIT( ch_data_config )
    ch_versions = ch_versions.mix(STIMULUS_SPLIT_SPLIT.out.versions)

    // transpose
    // and add sub config id called split_id
    ch_yaml_sub_config = STIMULUS_SPLIT_SPLIT.out.sub_config
        .transpose()
        .map { meta, yaml -> [ meta + [split_id: yaml.baseName], yaml] }

    emit:
    sub_config = ch_yaml_sub_config
    versions = ch_versions // channel: [ versions.yml ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
