# Wiki Extensions plugin for Redmine
# Copyright (C) 2009-2025  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
require 'redmine'
begin
  require 'config/initializers/session_store.rb'
rescue LoadError
end
# R7 still ships the Textile formatter/helper/RedCloth3 for legacy content, so the
# Textile-related patches below remain valid even though our content is CommonMark.
require 'redmine/wiki_formatting/textile/redcloth3'

# --- Redmine 7 loading (refs #108530) -------------------------------------------
# Was: $LOAD_PATH.unshift + Dir.foreach bulk-`require` of lib/*.rb + a nested
# `to_prepare` + ActionView::Base.class_eval. All replaced:
#
# * 26 of the 28 lib/*.rb follow Zeitwerk naming (wiki_extensions_foo.rb ->
#   WikiExtensionsFoo), so Zeitwerk eager-loads them — no bulk require.
# * TWO files reopen CORE classes (`class WikiController` / `class WikiPage`) as well
#   as defining their patch module, which Zeitwerk cannot own (the file name doesn't
#   match the constant). Those are explicitly ignored + required here.
# * The nested `to_prepare` never fires under R7 (init.rb already runs inside one),
#   so ProjectsHelperPatch is applied directly.
# * ActionView::Base.class_eval -> ActiveSupport.on_load(:action_view) (Rails 8.1
#   safe; avoids touching the class before it's ready).
plugin_lib = File.join(File.dirname(__FILE__), 'lib')
# Files Zeitwerk cannot own, so we ignore + require them explicitly:
#  * the two *_patch files reopen CORE classes (class WikiController / class WikiPage)
#    instead of defining the constant their filename implies;
#  * wiki_extensions_helper.rb defines a SECOND, nested constant
#    (ActionView::Helpers::WikiExtensionsHelper) besides the top-level one — Zeitwerk
#    only ever defines the expected one, so the nested module would never exist.
core_reopening_files = %w[
  wiki_extensions_wiki_controller_patch
  wiki_extensions_wiki_page_patch
  wiki_extensions_helper
].freeze

Rails.autoloaders.each do |loader|
  core_reopening_files.each { |f| loader.ignore(File.join(plugin_lib, "#{f}.rb")) }
end
core_reopening_files.each { |f| require File.join(plugin_lib, f) }

WikiExtensionsProjectsHelperPatch.apply if WikiExtensionsProjectsHelperPatch.respond_to?(:apply)

ActiveSupport.on_load(:action_view) do
  include ActionView::Helpers::WikiExtensionsHelper
end

Redmine::Plugin.register :redmine_wiki_extensions do
  name 'Redmine Wiki Extensions plugin'
  author 'Haruyuki Iida'
  author_url 'http://twitter.com/haru_iida'
  description 'This is a Wiki Extensions plugin for Redmine'
  url 'http://www.r-labs.org/projects/r-labs/wiki/Wiki_Extensions_en'
  version '7.0.0'
  requires_redmine :version_or_higher => '7.0.0'

  project_module :wiki_extensions do
    permission :wiki_extensions_vote, { :wiki_extensions => [:vote, :show_vote] }, :public => true
    permission :add_wiki_comment, { :wiki_extensions => [:add_comment, :reply_comment] }
    permission :delete_wiki_comments, { :wiki_extensions => [:destroy_comment] }
    permission :edit_wiki_comments, { :wiki_extensions => [:update_comment] }
    permission :show_wiki_extension_tabs, { :wiki_extensions => [:forward_wiki_page] }, :public => true
    permission :view_wiki_comment, { :wiki_extensions => [:show_comments] }, :public => true
    permission :show_wiki_tags, { :wiki_extensions => [:tag] }, :public => true
    permission :wiki_extensions_settings, { :wiki_extensions_settings => [:show, :update] }
  end

  menulist = [:wiki_extensions1, :wiki_extensions2, :wiki_extensions3, :wiki_extensions4, :wiki_extensions5]
  menulist.length.times { |i|
    no = i + 1
    before = :wiki
    before = menulist[i - 1] if i > 0

    menu :project_menu, menulist[i], { :controller => 'wiki_extensions', :action => 'forward_wiki_page', :menu_id => no }, :after => before,
                                                                                                                           :caption => Proc.new { |proj| WikiExtensionsMenu.title(proj.id, no) },
                                                                                                                           :if => Proc.new { |proj| WikiExtensionsMenu.enabled?(proj.id, no) }
  }

  RedCloth3::ALLOWED_TAGS << 'div'

  activity_provider :wiki_comment, :class_name => 'WikiExtensionsComment', :default => false
end
