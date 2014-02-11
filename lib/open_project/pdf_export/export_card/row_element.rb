#-- copyright
# OpenProject PDF Export Plugin
#
# Copyright (C)2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3.
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
#
# See doc/COPYRIGHT.md for more details.
#++

module OpenProject::PdfExport::ExportCard
  class RowElement
    include OpenProject::PdfExport::Exceptions

    def initialize(pdf, orientation, config, work_package)
      @pdf = pdf
      @orientation = orientation
      @config = config
      @columns_config = config["columns"]
      @work_package = work_package
      @column_elements = []

      raise BadlyFormedExportCardConfigurationError.new("Badly formed YAML") if @columns_config.nil?

      # Initialise column elements
      x_offset = 0
      padding = @orientation[:text_padding]

      @columns_config.each do |key, value|
        width = col_width(value) - padding
        column_orientation = @orientation.clone
        column_orientation[:x_offset] = x_offset + padding
        column_orientation[:width] = width - padding
        x_offset += width + padding

        @column_elements << ColumnElement.new(@pdf, key, value, column_orientation, @work_package)
      end
    end

    def col_width(col_config)
      cols_count = @columns_config.count
      w = col_config["width"]
      return @orientation[:width] / cols_count if w.nil?

      i = w.index("%") or w.length
      Float(w.slice(0, i)) / 100 * @orientation[:width]
    end

    def draw
      top_left = [@orientation[:x_offset], @orientation[:y_offset]]
      bounds = @orientation.slice(:width, :height)
      @pdf.bounding_box(top_left, bounds) do
        if @config["has_border"]
          @pdf.stroke_bounds
        end

        # Draw columns
        @column_elements.each do |c|
          c.draw
        end
      end

    end

    def self.prune_empty_groups(groups, wp)
      # Prune rows in groups
      groups.each do |gk, gv|
        self.prune_empty_rows(gv["rows"], wp)
      end

      # Prune empty groups
      groups.each do |gk, gv|
        if gv["rows"].count == 0
          groups.delete(gk)
        end
      end
    end

    def self.prune_empty_rows(rows, wp)
      rows.each do |rk, rv|
        # TODO RS: This is still only checking the first column, need to check all
        ck, cv = rv["columns"].first
        if !is_existing_column(ck, wp) || is_empty_column(ck, cv, wp)
          rows.delete(rk)
        end
      end
    end

    def self.is_empty_column(property_name, column, wp)
      if wp.respond_to?(property_name)
        value = wp.send(property_name)
      elsif customs = wp.custom_field_values.select {|cf| cf.custom_field.name == property_name} and customs.count > 0
        value = customs.first.value
      else
        value = ""
      end

      value = "" if value.is_a?(Array) && value.empty?
      value = value.to_s if !value.is_a?(String)

      !column["render_if_empty"] && value.empty?
    end

    def self.is_existing_column(property_name, wp)
      I18n.with_locale(I18n.locale) do
        wp.respond_to?(property_name) ||
          wp.custom_field_values.select {|cf| cf.custom_field.name == property_name}.count > 0
      end
    end
  end
end