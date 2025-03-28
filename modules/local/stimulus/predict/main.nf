process STIMULUS_PREDICT {
    tag "${meta.id}"
    label 'process_medium'
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta) , path(model), path(model_config), path(weigths)
    tuple val(meta2), path(data), path(data_config)

    output:
    tuple val(meta), path("${prefix}-pred.safetensors"), emit: predictions
    path "versions.yml"          , emit: versions

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ""
    """
    stimulus predict \
        -d ${data} \
        -e ${data_config} \
        -m ${model} \
        -c ${model_config} \
        -w ${weigths} \
        -o ${prefix}-pred.safetensors \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    touch ${prefix}-pred.safetensors

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
