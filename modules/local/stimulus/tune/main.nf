process STIMULUS_TUNE {
    tag "${meta.id}"
    label 'process_high'
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(transformed_data), path(data_sub_config)
    tuple val(meta2), path(model), path(model_config), path(initial_weights)

    output:
    tuple val(meta), path("${prefix}-best-model.safetensors")         , emit: model
    tuple val(meta), path("${prefix}-best-optimizer.opt")             , emit: optimizer
    tuple val(meta), path("optuna_results/artifacts")                 , emit: artifacts
    tuple val(meta), path("optuna_results/optuna_journal_storage.log"), emit: journal
    path "versions.yml"                                               , emit: versions
    // now we need to output these in this format for the predict module - thiw will have to be changed!
    tuple val(meta), path(model), path("best_config.json"), path("${prefix}-best-model.safetensors"), emit: model_tmp
    tuple val(meta), path(data_sub_config)                                                          , emit: data_config_tmp

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ""
    def use_initial_weights = initial_weights != [] ? "-w ${initial_weights}" : ""
    """
    stimulus tune \
        -d ${transformed_data} \
        -m ${model} \
        -e ${data_sub_config} \
        -c ${model_config} \
        -o ${prefix}-best-model.safetensors \
        -bo ${prefix}-best-optimizer.opt \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    touch ${prefix}-best-model.safetensors
    touch ${prefix}-best-optimizer.opt
    touch best_config.json
    touch TuneModel_stub.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
