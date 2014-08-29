# vim: sts=2 ts=2 sw=2 et ai
{% set gitolite = pillar.get('gitolite', {}) %}
{% set git_user_info = gitolite.get('user', {}) %}
{% set git_user_name = git_user_info.get('name', 'git') %}
{% set git_user_group = git_user_info.get('group', 'git') %}
{% set git_user_home = git_user_info.get('home', '/var/lib/git') %}
{% set git_user_home_mode = git_user_info.get('home_mode', '0700') %}
{% set git_user_fullname = git_user_info.get('fullname', 'Gitolite') %}
{% set gitolite_admin_pub = gitolite['admin_pub'] %}

# Ensure the gitolite user exists
{{ git_user_name }}_name:
  file.directory:
    - name: {{ git_user_name }}
    - home: {{ git_user_home }}
    - mode: {{ git_user_home_mode }}
    - require:
      - user: {{ git_user_name }}
      - group: {{ git_user_group }}

  group.present:
    - name: {{ git_user_group }}

  user.present:
    - name: {{ git_user_name }}
    - home: {{ git_user_home }}
    - shell: /bin/bash
    - fullname: {{ git_user_fullname }}
    - groups:
      - {{ git_user_group }}
    - require:
      - group: {{ git_user_group }}

# Ensure gitolite is installed
gitolite3:
  pkg:
    - installed
  file:
    - managed
    - name: {{ git_user_home }}/.gitolite.rc
    - source: salt://gitolite/files/gitolite.rc
    - user: {{ git_user_name }}
    - group: {{ git_user_group }}
    - mode: 0640
    - template: jinja

setup gitolite:
  file:
    - managed
    - user: git
    - group: git
    - name: /tmp/admin.pub
    - contents: {{ gitolite_admin_pub }}
  cmd.run:
    - gitolite setup -pk /tmp/admin.pub && rm /tmp/admin.pub
    - creates: {{ git_user_home }}/.gitolite
