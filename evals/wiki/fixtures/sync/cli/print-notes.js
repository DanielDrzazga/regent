// Wydruk notatek w konsoli — używa tego samego renderera co lista w web/.
import { renderNoteList } from '../web/note-list.js';

export function printNotes(notes) {
  console.log(renderNoteList({ status: 'ready', notes }));
}
