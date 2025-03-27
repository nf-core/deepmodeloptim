/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { STIMULUS_TUNE              } from '../../../modules/local/stimulus/tune'
include { CUSTOM_MODIFY_MODEL_CONFIG } from '../../../modules/local/custom/modify_model_config'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TUNE_WF {
    take:
    ch_transformed_data
    ch_yaml_sub_config
    ch_model
    ch_model_config
    ch_initial_weights
    tune_trials_range
    tune_replicates

    main:

    // Split the tune_trials_range into individual trials
    ch_versions = Channel.empty()


    // Modify the model config file to include the number of trials
    // This allows us to run multiple trials numbers with the same model
    CUSTOM_MODIFY_MODEL_CONFIG(
        ch_model_config.collect(),
        tune_trials_range
    )
    ch_versions = ch_versions.mix(CUSTOM_MODIFY_MODEL_CONFIG.out.versions)
    ch_model_config = CUSTOM_MODIFY_MODEL_CONFIG.out.config

    ch_tune_input = ch_transformed_data
        .map { meta, data ->
            [[split_id: meta.split_id, transform_id: meta.transform_id], meta, data]
        }
        .combine(
            ch_yaml_sub_config.map { meta, config ->
                [[split_id: meta.split_id, transform_id: meta.transform_id], config]
            }
            ,by: 0
        )
        .combine(ch_model.map{it[1]})
        .combine(ch_model_config)
        .combine(ch_initial_weights)    // when initial_weights is empty .map{it[1]} will return [], and not properly combined
        .combine(tune_replicates)
        .multiMap { key, meta, data, data_config, model, meta_model_config, model_config, meta_weights, initial_weights, n_replicate ->
            def meta_new = meta + [replicate: n_replicate] + [n_trials: meta_model_config.n_trials]
            data:
                [meta_new, data, data_config]
            model:
                [meta_new, model, model_config, initial_weights]
        }

    // run stimulus tune
    STIMULUS_TUNE(
        ch_tune_input.data,
        ch_tune_input.model
    )

    ch_versions = ch_versions.mix(STIMULUS_TUNE.out.versions)

    // parse output for evaluation block

    emit:
    best_model = STIMULUS_TUNE.out.model
    optimizer = STIMULUS_TUNE.out.optimizer
    tune_experiments = STIMULUS_TUNE.out.artifacts
    journal = STIMULUS_TUNE.out.journal
    versions = ch_versions // channel: [ versions.yml ]
    // these are temporaly needed for predict, it will be changed in the future!
    model_tmp = STIMULUS_TUNE.out.model_tmp
    data_config_tmp = STIMULUS_TUNE.out.data_config_tmp
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
