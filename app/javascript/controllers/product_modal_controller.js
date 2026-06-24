import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['modal'];

  open() {
    const modalId = this.element.dataset.productModalTargetModal;
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.showModal();
    }
  }
}
