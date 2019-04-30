# Manages the php-fpm pools config files
{% from 'php/ng/map.jinja' import php with context %}
{% from "php/ng/macro.jinja" import sls_block, serialize %}

# Simple path concatenation.
{% macro path_join(file, root) -%}
  {{ root ~ '/' ~ file }}
{%- endmacro %}

{% set pool_states = [] %}
{% set pillar_php_ng_version = salt['pillar.get']('php:ng:version', '7.0') %}

{% if salt['pillar.get']('php:ng:fpm:remove_default_pool_config', False) %}
{% if pillar_php_ng_version is iterable and pillar_php_ng_version is not string %}

{% for version in pillar_php_ng_version %}
{% set first_fpath = path_join('www.conf', php.lookup.fpm.pools) %}
{% set first_version = pillar_php_ng_version[0]|string %}
{% set fpath = first_fpath.replace(first_version, version) %}
remove default php {{ version }} pool config:
  file.absent:
  - name: {{ fpath }}
{% endfor %}

{% else %}

{% set fpath = path_join(config.get('filename', pool), php.lookup.fpm.pools) %}
remove default php pool config:
  file.absent:
  - name: {{ fpath }}
{% endif %}
{% endif %}

{% for pool, config in php.fpm.pools.items() %}
{% if pool == 'defaults' %}{% continue %}{% endif %}
{% for pkey, pvalues in config.get('settings', {}).items() %}
{% set pool_defaults = php.fpm.pools.get('defaults', {}).copy() %}
  {% do pool_defaults.update(pvalues) %}
  {% do pvalues.update(pool_defaults) %}
{% endfor %}
{% set state = 'php_fpm_pool_conf_' ~ loop.index0 %}

{% if pillar_php_ng_version is iterable and pillar_php_ng_version is not string %}
  {% set first_fpath = path_join(config.get('filename', pool), php.lookup.fpm.pools) %}
  {% set first_version = pillar_php_ng_version[0]|string %}
  {% set fpath = first_fpath.replace(first_version, config.get('phpversion', '7.0')) %}
{% else %}
  {% set fpath = path_join(config.get('filename', pool), php.lookup.fpm.pools) %}
{% endif %}

{{ state }}:
{% if config.enabled %}
  file.managed:
    {{ sls_block(config.get('opts', {})) }}
    - name: {{ fpath }}
    - source: salt://php/ng/files/php.ini
    - template: jinja
    - context:
        config: {{ serialize(config.get('settings', {})) }}
{% else %}
  file.absent:
    - name: {{ fpath }}
{% endif %}

{% do pool_states.append(state) %}
{% endfor %}
