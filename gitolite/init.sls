# vim: sts=2 ts=2 sw=2 et ai
{% set gitolite = pillar.get('gitolite', {}) %}
{% set git_user_info = gitolite.get('user', {}) %}
{% set git_user_name = git_user_info.get('name', 'git') %}
{% set git_user_group = git_user_info.get('group', 'git') %}
{% set git_user_additional_groups = git_user_info.get('additional_groups', []) %}
{% set git_user_home = git_user_info.get('home', '/var/lib/git') %}
{% set git_user_home_mode = git_user_info.get('home_mode', '0700') %}
{% set git_user_fullname = git_user_info.get('fullname', 'Gitolite') %}
{% set git_group_users = gitolite.get('git_group_users', []) %}
{% set gitolite_admin = gitolite.get('admin', {}) %}
{% set gitolite_admin_name = gitolite_admin.get('name', '') %}
{% set gitolite_admin_pub = gitolite_admin.get('pub', '') %}

# A special override that will be used to initialize a directory for local code
{% set gitolite_rc_local_code = salt['pillar.get']('gitolite:rc:local_code', '') %}
{% if gitolite_rc_local_code %}
  {% set gitolite_special_local_code_dir = salt['pillar.get']('gitolite:special:local_code_init', '') %}
  {% if gitolite_special_local_code_dir %}
    {% set gitolite_rc_local_code_dir = gitolite_special_local_code_dir %}
  {% else %}
    {% if gitolite_rc_local_code == '$rc{GL_ADMIN_BASE}/local' %}
      {% set gitolite_rc_local_code_dir = "%s/.gitolite/local"|format(git_user_home) %}
    {% endif %}
  {% endif %}
{% endif %}


# DO NOT EXECUTE UNLESS REQUIRED PILLARS ARE PRESENT
{% if gitolite_admin_name and gitolite_admin_pub %}

# Ensure the gitolite user exists
{{ git_user_name }}_name:
  file.directory:
    - name: {{ git_user_home }}
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - mode: {{ git_user_home_mode }}
    - require:
      - user: {{ git_user_name }}
      - group: {{ git_user_group }}

  group.present:
    - name: {{ git_user_group }}
    - addusers:
      {% for user in git_group_users %}
      - {{ user }}
      {% endfor %}

  user.present:
    - name: {{ git_user_name }}
    - home: {{ git_user_home }}
    - shell: /bin/bash
    - fullname: {{ git_user_fullname }}
    - groups:
      - {{ git_user_group }}
      {% for group in git_user_additional_groups %}
      - {{ group }}
      {% endfor %}
    - require:
      - group: {{ git_user_group }}

# Ensure gitolite is installed
gitolite3:
  pkg:
    - installed
  file:
    - managed
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - name: /tmp/{{ gitolite_admin_name }}.pub
    - contents: {{ gitolite_admin_pub }}

gitolite_setup_stage1:
  cmd.run:
    - name: gitolite setup -pk /tmp/{{ gitolite_admin_name }}.pub
    - creates: {{ git_user_home }}/.gitolite
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - require:
      - file: /tmp/raven.pub
      - pkg: gitolite3

customize_gitolite_rc:
  file:
    - managed
    - name: {{ git_user_home }}/.gitolite.rc
    - source: salt://gitolite/files/gitolite.rc
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - mode: 0640
    - template: jinja
    - require:
      - cmd: gitolite_setup_stage1

gitolite_setup_stage2:
  # Setup the local code directory if it is specified by the user

  {% if gitolite_rc_local_code_dir %}
  # This is only ever used if you've got a special spot for local code
  file.directory:
    - name: {{ gitolite_rc_local_code_dir }}
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - require:
      - pkg: gitolite3
      - user: {{ git_user_name }}
      - group: {{ git_user_group }}
    - require_in:
      - cmd: gitolite_setup_stage2
  {% endif %}

  cmd.run:
    - name: gitolite setup
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - require:
      - file: customize_gitolite_rc

{% endif %}
