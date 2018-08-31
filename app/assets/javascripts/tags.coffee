# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$(document).on 'turbolinks:load', ->
  tagTable = document.getElementById('tagTable')
  inputCourses = document.getElementById('inputCourses')
  inputTag = document.getElementById('inputTag')
  if inputTag?
    tagsWithId = JSON.parse(tagTable.dataset.tags)
    ids = tagsWithId.map (item) -> item.id
    sifter = new Sifter(tagsWithId)

  displayResults = ->
    searchString = $('#inputTag').val()
    selectedCourses = $('#inputCourses').val().map (item) -> parseInt(item)
    result = sifter.search(searchString,
      fields: [ 'title' ]
      sort: [ {
        field: 'title'
        direction: 'asc'
      } ])
    matchedIds = result.items.map (item) -> tagsWithId[item.id].id
    for id in ids
      row = document.getElementById('row-tag-' + id)
      courses = JSON.parse(row.dataset.courses).map (item) -> parseInt(item)
      if (id in matchedIds) && ($(courses).not($(courses).not($(selectedCourses)))).length > 0
        $(row).show()
      else
        $(row).hide()
    return

  $('#inputTag').on 'keyup', ->
    displayResults()
    return

  $('#inputCourses').on 'change', ->
    displayResults()
    return

  $('[id^="tag-form-"] :input').on 'change', ->
    id = this.dataset.id
    $('#tag-basics-warning-' + id).show()
    return

  $('[id^="tag-basics-cancel-"]').on 'click', ->
    location.reload()
    return

  $('#tags-edited-courses').on 'click', ->
    inputCourses.selectize.setValue(JSON.parse(this.dataset.courses))
    return

  $('#tags-all-courses').on 'click', ->
    inputCourses.selectize.setValue(JSON.parse(this.dataset.courses))
    return

  $('#tags-no-courses').on 'click', ->
    inputCourses.selectize.setValue()
    return

  $('[id^="new-tag-button"]').on 'click', ->
    $.ajax Routes.tag_modal_path(),
      type: 'GET'
      dataType: 'script'
      data: {
        related_tag: this.dataset.tag
        course: this.dataset.course
        section: this.dataset.section
        from: this.dataset.from
      }
    return
  return
