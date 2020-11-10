import { LightningElement } from 'lwc';

export default class PaginationNavigation extends LightningElement {
    handlePrev(event) {
        debugger;
        this.dispatchEvent(new CustomEvent('previous'));
    }

    handleNext(event) {
        this.dispatchEvent(new CustomEvent('next'));
    }
}