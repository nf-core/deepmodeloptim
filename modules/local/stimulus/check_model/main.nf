process CHECK_MODEL {

    tag "${meta.id}"
    label 'process_medium'
    // TODO: push image to nf-core quay.io
    container "docker.io/mathysgrapotte/stimulus-py:dev"

    input:
    tuple val(meta), path(data_config)
    tuple val(meta2), path(data)
    tuple val(meta3), path(model)
    tuple val(meta4), path(model_config)
    tuple val(meta5), path(initial_weights)

    output:
    stdout emit: standardout

    script:
    def args = task.ext.args ?: ''
    """
    stimulus check-model \
        -e ${data_config} \
        -d ${data} \
        -m ${model} \
        -c ${model_config} \
        -r "\${PWD}" \
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """

    stub:
    """
    echo passing check-model stub

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stimulus: \$(stimulus -v | cut -d ' ' -f 3)
    END_VERSIONS
    """
}
